#!/bin/bash
# inventory_export.sh - Export concise HW/SW inventory per host to a daily CSV (+details)
# Author: Shenhav_Hezi
# Version: 1.0
# Description:
#   Collects key inventory facts from one or many Linux servers and appends a row
#   to a daily CSV file. Also saves a per-host "details" snapshot (lscpu, lsblk, df, LVM, ip).
#
#   CSV fields:
#     date,host,fqdn,os,kernel,arch,virt,uptime,cpu_model,
#     sockets,cores_per_socket,threads_per_core,vcpus,mem_mb,swap_mb,
#     disk_total_gb,rootfs_use,vgs,lvs,pvs,vgs_size_gb,ip_list,default_gw,dns_servers,pkg_count
#
# Usage:
#   /usr/local/bin/inventory_export.sh
#
# Notes:
#   - Works in local or distributed mode (via servers.txt + SSH keys).
#   - Commands that aren't available on a host are skipped gracefully.

# ========================
# Configuration Variables
# ========================
SERVERLIST="/etc/linux_maint/servers.txt"      # One host per line; if missing → local mode
EXCLUDED="/etc/linux_maint/excluded.txt"       # Optional: hosts to skip
LOGFILE="/var/log/inventory_export.log"        # Script log

OUTPUT_DIR="/var/log/inventory"
DETAILS_DIR="${OUTPUT_DIR}/details"

SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=7 -o StrictHostKeyChecking=no"

# Email (optional): send a short summary when the run finishes
ALERT_EMAILS="/etc/linux_maint/emails.txt"     # Optional recipients (one per line)
MAIL_ON_RUN="false"
MAIL_SUBJECT_PREFIX='[Inventory Export]'

# ========================
# Helpers
# ========================
log(){ echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "$LOGFILE"; }
ensure_dirs(){ mkdir -p "$(dirname "$LOGFILE")" "$OUTPUT_DIR" "$DETAILS_DIR"; }

is_excluded(){
  local host="$1"
  [ -f "$EXCLUDED" ] || return 1
  grep -Fxq "$host" "$EXCLUDED"
}

ssh_do(){
  local host="$1"; shift
  if [ "$host" = "localhost" ]; then
    bash -lc "$*" 2>/dev/null
  else
    ssh $SSH_OPTS "$host" "$@" 2>/dev/null
  fi
}

send_mail(){
  local subject="$1" body="$2"
  [ "$MAIL_ON_RUN" = "true" ] || return 0
  [ -s "$ALERT_EMAILS" ] || return 0
  command -v mail >/dev/null || return 0
  while IFS= read -r to; do
    [ -n "$to" ] && printf "%s\n" "$body" | mail -s "$MAIL_SUBJECT_PREFIX $subject" "$to"
  done < "$ALERT_EMAILS"
}

csv_escape(){ local s="$1"; s="${s//\"/\"\"}"; printf "\"%s\"" "$s"; }

# Remote collector: emit KEY=value lines for all fields the CSV expects.
remote_inv_cmd='
DATE="$(date -Iseconds)"
host="$(hostname -s)"
fqdn="$(hostname -f 2>/dev/null || echo "$host")"
if [ -r /etc/os-release ]; then . /etc/os-release; os="$PRETTY_NAME"; else os="$(uname -s)"; fi
kernel="$(uname -r)"
arch="$(uname -m)"
virt="$(command -v systemd-detect-virt >/dev/null && systemd-detect-virt || echo unknown)"
uptime_p="$(uptime -p 2>/dev/null || echo "")"
cpu_model="$(lscpu 2>/dev/null | awk -F: "/Model name|Model Name/{sub(/^ +/,\"\",\$2); print \$2; exit}")"
sockets="$(lscpu 2>/dev/null | awk -F: "/Socket\\(s\\)/{gsub(/ /,\"\",\$2); print \$2; exit}")"
cores_per_socket="$(lscpu 2>/dev/null | awk -F: "/Core\\(s\\) per socket/{gsub(/ /,\"\",\$2); print \$2; exit}")"
threads_per_core="$(lscpu 2>/dev/null | awk -F: "/Thread\\(s\\) per core/{gsub(/ /,\"\",\$2); print \$2; exit}")"
vcpus="$(nproc 2>/dev/null || lscpu 2>/dev/null | awk -F: "/CPU\\(s\\)/{gsub(/ /,\"\",\$2); print \$2; exit}")"
mem_mb="$(free -m 2>/dev/null | awk \"/Mem:/{print \$2}\")"
swap_mb="$(free -m 2>/dev/null | awk \"/Swap:/{print \$2}\")"
disk_total_gb="$(lsblk -b -d -o SIZE,TYPE 2>/dev/null | awk \"/disk/{s+=\\$1} END{printf \\\"%.0f\\\", s/1024/1024/1024}\")"
rootfs_pct="$(df -P / 2>/dev/null | awk \"NR==2{print \\$5}\")"
vgs_count="$(vgs --noheadings 2>/dev/null | wc -l | tr -d \" \")"
lvs_count="$(lvs --noheadings 2>/dev/null | wc -l | tr -d \" \")"
pvs_count="$(pvs --noheadings 2>/dev/null | wc -l | tr -d \" \")"
vgs_size_gb="$(vgs --noheadings -o vg_size --units g 2>/dev/null | awk \"{gsub(/g/i,\\\"\\\"); if(\\$1>0) s+=\\$1} END{if(s>0) printf \\\"%.0f\\\", s;}\")"
ips="$(ip -o -4 addr show scope global 2>/dev/null | awk \"{print \\$4}\" | sed -e \"s#/.*##\" | paste -sd \";\" -)"
gw="$(ip route show default 2>/dev/null | awk \"/default/{print \\$3; exit}\")"
dns="$(awk \"/^nameserver/{print \\$2}\" /etc/resolv.conf 2>/dev/null | paste -sd \";\" -)"
pkg_count=\"\"
if command -v dpkg-query >/dev/null; then pkg_count=$(dpkg-query -f \".\" -W 2>/dev/null | wc -c); fi
if [ -z \"$pkg_count\" ] && command -v rpm >/dev/null; then pkg_count=$(rpm -qa 2>/dev/null | wc -l); fi

# Emit lines
echo "DATE=$DATE"
echo "HOST=$host"
echo "FQDN=$fqdn"
echo "OS=$os"
echo "KERNEL=$kernel"
echo "ARCH=$arch"
echo "VIRT=$virt"
echo "UPTIME=$uptime_p"
echo "CPU_MODEL=$cpu_model"
echo "SOCKETS=$sockets"
echo "CORES_PER_SOCKET=$cores_per_socket"
echo "THREADS_PER_CORE=$threads_per_core"
echo "VCPUS=$vcpus"
echo "MEM_MB=$mem_mb"
echo "SWAP_MB=$swap_mb"
echo "DISK_TOTAL_GB=$disk_total_gb"
echo "ROOTFS_USE=$rootfs_pct"
echo "VGS=$vgs_count"
echo "LVS=$lvs_count"
echo "PVS=$pvs_count"
echo "VGS_SIZE_GB=$vgs_size_gb"
echo "IPS=$ips"
echo "GW=$gw"
echo "DNS=$dns"
echo "PKG_COUNT=$pkg_count"
'

# Remote "details" snapshot for human-friendly context
remote_details_cmd='
echo "===== Host ====="; hostnamectl 2>/dev/null || true
echo
echo "===== CPU ====="; lscpu 2>/dev/null || true
echo
echo "===== Memory ====="; free -h 2>/dev/null || true
echo
echo "===== Block Devices (lsblk) ====="; lsblk -o NAME,TYPE,SIZE,ROTA,SERIAL,MODEL 2>/dev/null || true
echo
echo "===== Filesystems (df -hT) ====="; df -hT 2>/dev/null || true
echo
echo "===== LVM (vgs) ====="; vgs -o vg_name,vg_size,vg_free,vg_attr --noheadings 2>/dev/null || true
echo
echo "===== LVM (lvs) ====="; lvs -o vg_name,lv_name,lv_size,attr --noheadings 2>/dev/null || true
echo
echo "===== Network (ip -4 addr) ====="; ip -o -4 addr show 2>/dev/null || true
echo
echo "===== Routes ====="; ip route 2>/dev/null || true
'

write_csv_header_if_needed(){
  local csv_file="$1"
  if [ ! -f "$csv_file" ]; then
    printf "%s\n" "date,host,fqdn,os,kernel,arch,virt,uptime,cpu_model,sockets,cores_per_socket,threads_per_core,vcpus,mem_mb,swap_mb,disk_total_gb,rootfs_use,vgs,lvs,pvs,vgs_size_gb,ip_list,default_gw,dns_servers,pkg_count" > "$csv_file"
  fi
}

append_csv_row(){
  local csv_file="$1"; shift
  # args: 25 fields in order
  {
    csv_escape "$1";  printf ",";  # date
    csv_escape "$2";  printf ",";  # host
    csv_escape "$3";  printf ",";  # fqdn
    csv_escape "$4";  printf ",";  # os
    csv_escape "$5";  printf ",";  # kernel
    csv_escape "$6";  printf ",";  # arch
    csv_escape "$7";  printf ",";  # virt
    csv_escape "$8";  printf ",";  # uptime
    csv_escape "$9";  printf ",";  # cpu_model
    csv_escape "${10}"; printf ",";# sockets
    csv_escape "${11}"; printf ",";# cores_per_socket
    csv_escape "${12}"; printf ",";# threads_per_core
    csv_escape "${13}"; printf ",";# vcpus
    csv_escape "${14}"; printf ",";# mem_mb
    csv_escape "${15}"; printf ",";# swap_mb
    csv_escape "${16}"; printf ",";# disk_total_gb
    csv_escape "${17}"; printf ",";# rootfs_use
    csv_escape "${18}"; printf ",";# vgs
    csv_escape "${19}"; printf ",";# lvs
    csv_escape "${20}"; printf ",";# pvs
    csv_escape "${21}"; printf ",";# vgs_size_gb
    csv_escape "${22}"; printf ",";# ip_list
    csv_escape "${23}"; printf ",";# default_gw
    csv_escape "${24}"; printf ",";# dns_servers
    csv_escape "${25}";          # pkg_count
    printf "\n"
  } >> "$csv_file"
}

collect_one_host(){
  local host="$1" date_short="$2" csv_file="$3"

  # reachability (skip check for localhost)
  if [ "$host" != "localhost" ]; then
    if ! ssh_do "$host" "echo ok" | grep -q ok; then
      log "[$host] ERROR: SSH unreachable."
      return
    fi
  fi

  # --- inventory values ---
  declare -A V
  while IFS='=' read -r k v; do
    [ -z "$k" ] && continue
    V["$k"]="$v"
  done < <(ssh_do "$host" bash -lc "'$remote_inv_cmd'")

  append_csv_row "$csv_file" \
    "${V[DATE]}" "${V[HOST]}" "${V[FQDN]}" "${V[OS]}" "${V[KERNEL]}" "${V[ARCH]}" "${V[VIRT]}" "${V[UPTIME]}" \
    "${V[CPU_MODEL]}" "${V[SOCKETS]}" "${V[CORES_PER_SOCKET]}" "${V[THREADS_PER_CORE]}" "${V[VCPUS]}" \
    "${V[MEM_MB]}" "${V[SWAP_MB]}" "${V[DISK_TOTAL_GB]}" "${V[ROOTFS_USE]}" \
    "${V[VGS]}" "${V[LVS]}" "${V[PVS]}" "${V[VGS_SIZE_GB]}" \
    "${V[IPS]}" "${V[GW]}" "${V[DNS]}" "${V[PKG_COUNT]}"

  log "[$host] row appended: os=${V[OS]} arch=${V[ARCH]} cpu=${V[CPU_MODEL]} mem=${V[MEM_MB]}MB disks=${V[DISK_TOTAL_GB]}GB vgs=${V[VGS]} lvs=${V[LVS]}"

  # --- details snapshot ---
  local details="${DETAILS_DIR}/${V[HOST]}_${date_short}.txt"
  ssh_do "$host" bash -lc "'$remote_details_cmd'" > "$details"
  log "[$host] details -> $details"
}

# ========================
# Main
# ========================
ensure_dirs
DATE_SHORT="$(date +%Y-%m-%d)"
CSV_FILE="${OUTPUT_DIR}/inventory_${DATE_SHORT}.csv"

write_csv_header_if_needed "$CSV_FILE"

log "=== Inventory Export Started (CSV: $CSV_FILE) ==="

if [ -f "$SERVERLIST" ]; then
  while IFS= read -r HOST; do
    [ -z "$HOST" ] && continue
    is_excluded "$HOST" && { log "Skipping $HOST (excluded)"; continue; }
    collect_one_host "$HOST" "$DATE_SHORT" "$CSV_FILE"
  done < "$SERVERLIST"
else
  collect_one_host "localhost" "$DATE_SHORT" "$CSV_FILE"
fi

log "=== Inventory Export Finished ==="

if [ "$MAIL_ON_RUN" = "true" ]; then
  send_mail "Inventory CSV ready" "Inventory written to: $CSV_FILE"
fi
