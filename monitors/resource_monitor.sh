#!/usr/bin/env bash
set -euo pipefail

# Resource monitor: CPU/load, memory, swap pressure (local runner only)
# Emits summary with reasons: high_load, high_mem, swap_thrash

. "${LINUX_MAINT_LIB:-/usr/local/lib/linux_maint.sh}" || { echo "Missing ${LINUX_MAINT_LIB:-/usr/local/lib/linux_maint.sh}"; exit 1; }
LM_PREFIX="[resource_monitor] "
LM_LOGFILE="${LM_LOGFILE:-/var/log/resource_monitor.log}"

lm_require_singleton "resource_monitor"

# Minimal deps: /proc is required.
[ -r /proc/loadavg ] || { lm_summary "resource_monitor" "localhost" "UNKNOWN" reason=missing_dependency dep="/proc/loadavg"; exit 3; }
[ -r /proc/meminfo ] || { lm_summary "resource_monitor" "localhost" "UNKNOWN" reason=missing_dependency dep="/proc/meminfo"; exit 3; }

# Thresholds (tunable)
: "${LM_RESOURCE_LOAD_WARN:=4.0}"
: "${LM_RESOURCE_LOAD_CRIT:=8.0}"
: "${LM_RESOURCE_MEM_WARN_PCT:=90}"
: "${LM_RESOURCE_MEM_CRIT_PCT:=95}"
: "${LM_RESOURCE_SWAP_USED_WARN_PCT:=25}"
: "${LM_RESOURCE_SWAP_USED_CRIT_PCT:=50}"

# For swap thrash, prefer pswpin/pswpout counters if available.
: "${LM_RESOURCE_SWAP_THRASH_WARN_RATE:=50}"   # pages/sec (best-effort)
: "${LM_RESOURCE_SWAP_THRASH_CRIT_RATE:=200}"  # pages/sec (best-effort)

read_load1() {
  awk '{print $1}' /proc/loadavg 2>/dev/null || echo "0"
}

read_meminfo_kb() {
  # prints: mem_total_kb mem_avail_kb swap_total_kb swap_free_kb
  awk '
    $1=="MemTotal:"{mt=$2}
    $1=="MemAvailable:"{ma=$2}
    $1=="SwapTotal:"{st=$2}
    $1=="SwapFree:"{sf=$2}
    END{printf "%s %s %s %s\n", mt+0, ma+0, st+0, sf+0}
  ' /proc/meminfo 2>/dev/null || echo "0 0 0 0"
}

pct_used() {
  local total="$1" free="$2"
  if [ "$total" -le 0 ]; then
    echo 0
    return 0
  fi
  echo $(( ( (total - free) * 100 ) / total ))
}

# Best-effort swap thrash rate from /proc/vmstat (pages/sec over ~1s)
read_vmstat_pages() {
  [ -r /proc/vmstat ] || return 1
  awk '
    $1=="pswpin"{in=$2}
    $1=="pswpout"{out=$2}
    END{printf "%s %s\n", in+0, out+0}
  ' /proc/vmstat 2>/dev/null
}

calc_swap_thrash_rate() {
  local a b
  a="$(read_vmstat_pages 2>/dev/null)" || return 1
  sleep 1
  b="$(read_vmstat_pages 2>/dev/null)" || return 1
  local in1 out1 in2 out2
  in1="${a%% *}"; out1="${a##* }"
  in2="${b%% *}"; out2="${b##* }"
  # pages/sec (delta)
  echo $(( (in2 - in1) + (out2 - out1) ))
}

load1="$(read_load1)"
read -r mem_total_kb mem_avail_kb swap_total_kb swap_free_kb < <(read_meminfo_kb)

mem_used_pct=0
if [ "$mem_total_kb" -gt 0 ]; then
  mem_used_pct=$(( ( (mem_total_kb - mem_avail_kb) * 100 ) / mem_total_kb ))
fi

swap_used_pct="$(pct_used "$swap_total_kb" "$swap_free_kb")"

# Evaluate status
status="OK"
reason=""

# Memory pressure
if [ "$mem_used_pct" -ge "$LM_RESOURCE_MEM_CRIT_PCT" ]; then
  status="CRIT"; reason="high_mem"
elif [ "$mem_used_pct" -ge "$LM_RESOURCE_MEM_WARN_PCT" ] && [ "$status" != "CRIT" ]; then
  status="WARN"; reason="high_mem"
fi

# Swap usage pressure (only if swap exists)
if [ "$swap_total_kb" -gt 0 ]; then
  if [ "$swap_used_pct" -ge "$LM_RESOURCE_SWAP_USED_CRIT_PCT" ]; then
    status="CRIT"; reason="${reason:-swap_thrash}"
  elif [ "$swap_used_pct" -ge "$LM_RESOURCE_SWAP_USED_WARN_PCT" ] && [ "$status" = "OK" ]; then
    status="WARN"; reason="${reason:-swap_thrash}"
  fi
fi

# Swap thrash rate (best-effort)
swap_thrash_rate=""
if swap_thrash_rate="$(calc_swap_thrash_rate 2>/dev/null)"; then
  if [ "$swap_thrash_rate" -ge "$LM_RESOURCE_SWAP_THRASH_CRIT_RATE" ]; then
    status="CRIT"; reason="swap_thrash"
  elif [ "$swap_thrash_rate" -ge "$LM_RESOURCE_SWAP_THRASH_WARN_RATE" ] && [ "$status" != "CRIT" ]; then
    status="WARN"; reason="swap_thrash"
  fi
fi

# Load pressure (simple; 1m loadavg)
# Compare as floats via awk.
load_sev="$(awk -v l="$load1" -v w="$LM_RESOURCE_LOAD_WARN" -v c="$LM_RESOURCE_LOAD_CRIT" 'BEGIN{if(l>=c)print 2; else if(l>=w)print 1; else print 0}')"
if [ "$load_sev" -ge 2 ]; then
  status="CRIT"; reason="high_load"
elif [ "$load_sev" -ge 1 ] && [ "$status" != "CRIT" ]; then
  status="WARN"; reason="${reason:-high_load}"
fi

# Emit summary
args=(
  load1="$load1"
  mem_used_pct="$mem_used_pct"
  swap_used_pct="$swap_used_pct"
  mem_total_kb="$mem_total_kb"
  mem_avail_kb="$mem_avail_kb"
  swap_total_kb="$swap_total_kb"
  swap_free_kb="$swap_free_kb"
)

if [ -n "$swap_thrash_rate" ]; then
  args+=(swap_thrash_rate="$swap_thrash_rate")
fi

if [ "$status" != "OK" ] && [ -n "$reason" ]; then
  lm_summary "resource_monitor" "localhost" "$status" reason="$reason" "${args[@]}"
else
  lm_summary "resource_monitor" "localhost" "$status" "${args[@]}"
fi
