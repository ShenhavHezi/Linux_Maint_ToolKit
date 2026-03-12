#!/usr/bin/env bash
# Menu workflow helpers for linux-maint.

run_menu_settings(){
  while true; do
    local choice
    local backend_cur="${LM_TUI_BACKEND:-auto}"
    local refresh_cur="${LM_TUI_DASH_REFRESH:-0}"
    local view_cur="${LM_TUI_DEFAULT_STATUS_VIEW:-table}"
    local p_cur="${LM_TUI_DEFAULT_PROBLEMS:-20}"
    local r_cur="${LM_TUI_DEFAULT_REASONS:-5}"
    local prev_cur="${LM_TUI_PREVIEW:-1}"
    local sh_cur="${LM_TUI_SHORTCUTS:-1}"
    local compact_cur="${LM_TUI_COMPACT:-0}"
    local lowc_cur="${LM_TUI_LOW_COLOR:-0}"
    local confirm_cur="${LM_TUI_CONFIRM_RISKY:-1}"
    TUI_SHORTCUT_CONTEXT="settings"
    choice="$(tui_menu_prompt_safe "Menu settings" \
      backend "Backend preference (current: $backend_cur) [b]" \
      refresh "Dashboard refresh seconds (current: $refresh_cur) [r]" \
      view "Default status view (current: $view_cur) [v]" \
      limits "Default problems/reasons (current: $p_cur/$r_cur) [l]" \
      preview "Command preview before run (current: $prev_cur) [p]" \
      shortcuts "Shortcuts r/s/t/d/c/h/x (current: $sh_cur) [k]" \
      compact "Compact menu mode (current: $compact_cur) [m]" \
      lowcolor "Low-color mode (current: $lowc_cur) [o]" \
      confirmrisk "Confirm risky actions (current: $confirm_cur) [a]" \
      save "Save settings to $(menu_settings_path) [s]" \
      reset "Reset settings to defaults [x]" \
      back "Back [q]")"
    [[ "$TUI_MENU_RC" -eq 0 && -n "${choice:-}" ]] || break
    choice="$(normalize_menu_choice "$choice")"
    choice="$(map_menu_shortcut "$choice" "settings")"
    case "$choice" in
      backend)
        local b
        b="$(tui_menu_prompt_safe "Pick backend preference" auto "Auto detect" gum "gum" dialog "dialog" whiptail "whiptail" back "Back")"
        if [[ "$TUI_MENU_RC" -eq 0 && -n "${b:-}" ]]; then
          b="$(normalize_menu_choice "$b")"
          case "$b" in
            auto) unset LM_TUI_BACKEND ;;
            gum|dialog|whiptail) export LM_TUI_BACKEND="$b" ;;
          esac
        fi
        ;;
      refresh)
        local v
        tui_input_capture "Dashboard refresh seconds (0 disables)" "${LM_TUI_DASH_REFRESH:-0}"
        v="$TUI_INPUT_VALUE"
        if [[ "$TUI_INPUT_RC" -eq 0 && "$v" =~ ^[0-9]+$ ]]; then
          export LM_TUI_DASH_REFRESH="$v"
        fi
        ;;
      view)
        local v
        v="$(tui_menu_prompt_safe "Default status view" table "Table" compact "Compact" back "Back")"
        if [[ "$TUI_MENU_RC" -eq 0 && -n "${v:-}" ]]; then
          v="$(normalize_menu_choice "$v")"
          [[ "$v" != "back" ]] && export LM_TUI_DEFAULT_STATUS_VIEW="$v"
        fi
        ;;
      limits)
        local p r
        tui_input_capture "Default problems count" "${LM_TUI_DEFAULT_PROBLEMS:-20}"
        p="$TUI_INPUT_VALUE"
        if [[ "$TUI_INPUT_RC" -eq 0 && "$p" =~ ^[0-9]+$ ]]; then export LM_TUI_DEFAULT_PROBLEMS="$p"; fi
        tui_input_capture "Default reasons count" "${LM_TUI_DEFAULT_REASONS:-5}"
        r="$TUI_INPUT_VALUE"
        if [[ "$TUI_INPUT_RC" -eq 0 && "$r" =~ ^[0-9]+$ ]]; then export LM_TUI_DEFAULT_REASONS="$r"; fi
        ;;
      preview)
        local v
        v="$(tui_menu_prompt_safe "Command preview" 1 "Enabled" 0 "Disabled" back "Back")"
        if [[ "$TUI_MENU_RC" -eq 0 && -n "${v:-}" ]]; then
          v="$(normalize_menu_choice "$v")"
          [[ "$v" != "back" ]] && export LM_TUI_PREVIEW="$v"
        fi
        ;;
      shortcuts)
        local v
        v="$(tui_menu_prompt_safe "Keyboard shortcuts" 1 "Enabled (menu keys)" 0 "Disabled" back "Back")"
        if [[ "$TUI_MENU_RC" -eq 0 && -n "${v:-}" ]]; then
          v="$(normalize_menu_choice "$v")"
          [[ "$v" != "back" ]] && export LM_TUI_SHORTCUTS="$v"
        fi
        ;;
      compact)
        local v
        v="$(tui_menu_prompt_safe "Compact menu mode" 1 "Enabled" 0 "Disabled" back "Back")"
        if [[ "$TUI_MENU_RC" -eq 0 && -n "${v:-}" ]]; then
          v="$(normalize_menu_choice "$v")"
          [[ "$v" != "back" ]] && export LM_TUI_COMPACT="$v"
        fi
        ;;
      lowcolor)
        local v
        v="$(tui_menu_prompt_safe "Low-color mode" 1 "Enabled" 0 "Disabled" back "Back")"
        if [[ "$TUI_MENU_RC" -eq 0 && -n "${v:-}" ]]; then
          v="$(normalize_menu_choice "$v")"
          [[ "$v" != "back" ]] && export LM_TUI_LOW_COLOR="$v"
        fi
        ;;
      confirmrisk)
        local v
        v="$(tui_menu_prompt_safe "Confirm risky actions" 1 "Enabled" 0 "Disabled" back "Back")"
        if [[ "$TUI_MENU_RC" -eq 0 && -n "${v:-}" ]]; then
          v="$(normalize_menu_choice "$v")"
          [[ "$v" != "back" ]] && export LM_TUI_CONFIRM_RISKY="$v"
        fi
        ;;
      save)
        if save_menu_settings; then
          tui_msgbox "Saved menu settings to $(menu_settings_path)"
        else
          tui_msgbox "Failed to save menu settings to $(menu_settings_path)"
        fi
        ;;
      reset)
        if tui_yesno "Reset all menu settings to defaults?"; then
          menu_settings_reset_defaults
          normalize_menu_settings
          tui_msgbox "Menu settings reset to defaults."
        fi
        ;;
      back) break ;;
    esac
    if [[ "${TUI_RETURN_TO_MAIN:-0}" == "1" ]]; then
      break
    fi
  done
}

run_menu_run(){
  while true; do
    local choice
    TUI_SHORTCUT_CONTEXT="run"
    choice="$(tui_menu_prompt_safe "Run checks" \
      run "Execute: run checks now (live output) [r] [changes]" \
      plan "Preview: resolved run plan only [p]" \
      wizard "Guide: guided run setup wizard [w]" \
      back "Back to main menu [b]")"
    local rc=$TUI_MENU_RC
    if [[ $rc -ne 0 || -z "${choice:-}" ]]; then
      break
    fi
    choice="$(normalize_menu_choice "$choice")"
    choice="$(map_menu_shortcut "$choice" "run")"
    case "$choice" in
      run)
        local run_rc=0
        tui_run_live "linux-maint run" "$0" run
        run_rc="${TUI_LAST_CMD_RC:-0}"
        if [[ "$run_rc" -ne 130 ]]; then
          tui_run_next_steps "$run_rc"
        fi
        ;;
      plan)
        tui_run_cmd "linux-maint run --plan" "$0" run --plan
        ;;
      wizard)
        tui_run_wizard
        ;;
      back)
        break
        ;;
    esac
    if [[ "${TUI_RETURN_TO_MAIN:-0}" == "1" ]]; then
      break
    fi
  done
}

run_menu_reports(){
  while true; do
    local choice
    TUI_SHORTCUT_CONTEXT="reports"
    choice="$(tui_menu_prompt_safe "Reports and status" \
      status "View: current status snapshot [s]" \
      dashboard "View: live dashboard overview [d]" \
      drilldown "Analyze: drill down by status, monitor, host, and reason [l]" \
      report "Review: short report summary [r]" \
      trend "Analyze: severity trend across recent runs [t]" \
      runtimes "Analyze: slowest monitors across recent runs [u]" \
      back "Back to main menu [b]")"
    local rc=$TUI_MENU_RC
    if [[ $rc -ne 0 || -z "${choice:-}" ]]; then
      break
    fi
    choice="$(normalize_menu_choice "$choice")"
    choice="$(map_menu_shortcut "$choice" "reports")"
    case "$choice" in
      dashboard)
        if [[ "$TUI_BACKEND" == "gum" ]]; then
          tui_gum_dashboard
        else
          tui_run_cmd "linux-maint status --table" "$0" status --table
        fi
        ;;
      status)
        if [[ "${LM_TUI_DEFAULT_STATUS_VIEW:-table}" == "compact" ]]; then
          tui_run_cmd "linux-maint status --compact" "$0" status --compact
        else
          tui_run_cmd "linux-maint status --table" "$0" status --table
        fi
        ;;
      drilldown)
        tui_status_drilldown
        ;;
      report)
        tui_run_cmd "linux-maint report --short --no-trend" "$0" report --short --no-trend
        ;;
      trend)
        tui_run_cmd "linux-maint trend --last 10" "$0" trend --last 10
        ;;
      runtimes)
        tui_run_cmd "linux-maint runtimes --last 10" "$0" runtimes --last 10
        ;;
      back)
        break
        ;;
    esac
    if [[ "${TUI_RETURN_TO_MAIN:-0}" == "1" ]]; then
      break
    fi
  done
}

run_menu_tools(){
  while true; do
    local choice
    TUI_SHORTCUT_CONTEXT="tools"
    choice="$(tui_menu_prompt_safe "Tools and automation" \
      check "Validate: config and readiness checks [c]" \
      summary "Inspect: one-line health summary [s]" \
      diff "Inspect: changes since previous run [d]" \
      history "Inspect: recent run history [h]" \
      runindex "Inspect: run index stats and retention [r]" \
      metrics_prom "Export: Prometheus metrics [m]" \
      metrics_json "Export: metrics JSON [j]" \
      pack_logs "Support: create redacted support bundle [p] [changes]" \
      back "Back to main menu [b]")"
    local rc=$TUI_MENU_RC
    if [[ $rc -ne 0 || -z "${choice:-}" ]]; then
      break
    fi
    choice="$(normalize_menu_choice "$choice")"
    choice="$(map_menu_shortcut "$choice" "tools")"
    case "$choice" in
      check)
        tui_run_cmd "linux-maint check" "$0" check
        ;;
      summary)
        tui_run_cmd "linux-maint summary" "$0" summary --no-color
        ;;
      diff)
        tui_run_cmd "linux-maint diff" "$0" diff
        ;;
      history)
        tui_run_cmd "linux-maint history --table" "$0" history --table
        ;;
      runindex)
        tui_run_cmd "linux-maint run-index --stats" "$0" run-index --stats
        ;;
      metrics_prom)
        tui_run_cmd "linux-maint metrics --prom" "$0" metrics --prom
        ;;
      metrics_json)
        tui_run_cmd "linux-maint metrics --json" "$0" metrics --json
        ;;
      pack_logs)
        tui_pack_logs_wizard || true
        ;;
      back)
        break
        ;;
    esac
    if [[ "${TUI_RETURN_TO_MAIN:-0}" == "1" ]]; then
      break
    fi
  done
}

run_menu_help(){
  while true; do
    local choice
    TUI_SHORTCUT_CONTEXT="help"
    choice="$(tui_menu_prompt_safe "Help and docs" \
      quickref "Open: quick command reference [h]" \
      faq "Open: FAQ and operator tips [f]" \
      troubleshooting "Open: troubleshooting guide [t]" \
      reasons "Open: reason token catalog [r]" \
      monitors "Open: monitor matrix and purpose [m]" \
      about "Inspect: version and project details [a]" \
      explain_reason "Explain: one reason token [e]" \
      explain_monitor "Explain: one monitor [o]" \
      explain_status "Explain: status meanings [s]" \
      back "Back to main menu [b]")"
    local rc=$TUI_MENU_RC
    if [[ $rc -ne 0 || -z "${choice:-}" ]]; then
      break
    fi
    choice="$(normalize_menu_choice "$choice")"
    choice="$(map_menu_shortcut "$choice" "help")"
    case "$choice" in
      quickref)
        tui_view_file "Quick reference" "$(find_doc_file QUICK_REFERENCE.md)"
        ;;
      faq)
        tui_view_file "FAQ" "$(find_doc_file FAQ.md)"
        ;;
      troubleshooting)
        tui_view_file "Troubleshooting" "$(find_doc_file troubleshooting.md)"
        ;;
      reasons)
        tui_view_file "Reasons" "$(find_doc_file REASONS.md)"
        ;;
      monitors)
        tui_view_file "Monitors matrix" "$(find_doc_file MONITORS_MATRIX.md)"
        ;;
      about)
        tui_about
        ;;
      explain_reason)
        local token
        tui_input_capture "Reason token" "e.g. disk_full"
        token="$TUI_INPUT_VALUE"
        if [[ "$TUI_INPUT_RC" -eq 0 && -n "$token" ]]; then
          tui_run_cmd "linux-maint explain reason $token" "$0" explain reason "$token"
        fi
        ;;
      explain_monitor)
        local mon
        tui_input_capture "Monitor name" "e.g. service_monitor"
        mon="$TUI_INPUT_VALUE"
        if [[ "$TUI_INPUT_RC" -eq 0 && -n "$mon" ]]; then
          tui_run_cmd "linux-maint explain monitor $mon" "$0" explain monitor "$mon"
        fi
        ;;
      explain_status)
        local s
        s="$(tui_menu_prompt_safe "Pick status" \
          OK "Healthy" \
          WARN "Warning" \
          CRIT "Critical" \
          UNKNOWN "Unknown" \
          SKIP "Skipped" \
          back "Back")"
        if [[ "$TUI_MENU_RC" -eq 0 && -n "$s" ]]; then
          s="$(normalize_menu_choice "$s")"
          if [[ "$s" != "back" ]]; then
            tui_run_cmd "linux-maint explain status $s" "$0" explain status "$s"
          fi
        fi
        ;;
      back)
        break
        ;;
    esac
    if [[ "${TUI_RETURN_TO_MAIN:-0}" == "1" ]]; then
      break
    fi
  done
}

run_menu_diagnostics(){
  while true; do
    local choice
    TUI_SHORTCUT_CONTEXT="diagnostics"
    choice="$(tui_menu_prompt_safe "Diagnostics and recovery" \
      incident "Guide: incident response workflow [i]" \
      doctor "Diagnose: doctor checks and fixes [d] [changes]" \
      selfcheck "Validate: self-check (safe) [s]" \
      secprofile "Inspect: strict security profile [p]" \
      logslive "Stream: latest wrapper log live [l]" \
      logs "View: latest log tail [g]" \
      back "Back to main menu [b]")"
    local rc=$TUI_MENU_RC
    if [[ $rc -ne 0 || -z "${choice:-}" ]]; then
      break
    fi
    choice="$(normalize_menu_choice "$choice")"
    choice="$(map_menu_shortcut "$choice" "diagnostics")"
    case "$choice" in
      incident)
        run_menu_incident_mode
        ;;
      logslive)
        tui_tail_logs
        ;;
      logs)
        tui_run_cmd "linux-maint logs 200" "$0" logs 200
        ;;
      doctor)
        tui_run_cmd "linux-maint doctor" "$0" doctor
        ;;
      selfcheck)
        tui_run_cmd "linux-maint self-check" "$0" self-check
        ;;
      secprofile)
        tui_run_cmd "linux-maint security-profile --strict" "$0" security-profile --strict
        ;;
      back)
        break
        ;;
    esac
    if [[ "${TUI_RETURN_TO_MAIN:-0}" == "1" ]]; then
      break
    fi
  done
}

run_menu_incident_mode(){
  local status_json overall top_reason top_monitor top_host summary_text recommendation
  status_json="$(NO_COLOR=1 "$0" status --json --problems 12 --reasons 6 2>/dev/null || true)"
  summary_text="$(STATUS_JSON="$status_json" python3 - <<'PY'
import json, os
raw = os.environ.get("STATUS_JSON","")
overall = "UNKNOWN"
top_reason = "-"
top_monitor = "-"
top_host = "-"
try:
    obj = json.loads(raw or "{}")
except Exception:
    obj = {}
overall = str((obj.get("last_status") or {}).get("overall") or "UNKNOWN")
rr = obj.get("reason_rollup") or []
if rr:
    top_reason = str((rr[0] or {}).get("reason") or "-")
problems = obj.get("problems") or []
if problems:
    top_monitor = str((problems[0] or {}).get("monitor") or "-")
    top_host = str((problems[0] or {}).get("host") or "-")
print(f"overall={overall}")
print(f"top_reason={top_reason}")
print(f"top_monitor={top_monitor}")
print(f"top_host={top_host}")
PY
)"
  overall="$(printf '%s\n' "$summary_text" | awk -F= '/^overall=/{print $2; exit}')"
  top_reason="$(printf '%s\n' "$summary_text" | awk -F= '/^top_reason=/{print $2; exit}')"
  top_monitor="$(printf '%s\n' "$summary_text" | awk -F= '/^top_monitor=/{print $2; exit}')"
  top_host="$(printf '%s\n' "$summary_text" | awk -F= '/^top_host=/{print $2; exit}')"
  recommendation="$(tui_incident_recommendation_summary "$top_reason" "$top_monitor" "$top_host")"
  tui_msgbox "Incident mode context:\noverall=${overall:-UNKNOWN}\ntop_reason=${top_reason:--}\ntop_monitor=${top_monitor:--}\ntop_host=${top_host:--}\nrecommended=${recommendation}\n\nChoose guided next steps."

  while true; do
    local choice
    TUI_SHORTCUT_CONTEXT="incident"
    choice="$(tui_menu_prompt_safe "Incident mode" \
      recommended "Execute: recommended triage step [c]" \
      focused_run "Execute: focused health checks [f]" \
      status_reasons "Review: top status reasons (10) [s]" \
      doctor "Diagnose: run doctor [d]" \
      bundle "Support: create redacted bundle [b]" \
      short_report "Review: short report [r]" \
      back "Back [q]")"
    [[ "$TUI_MENU_RC" -eq 0 && -n "${choice:-}" ]] || break
    choice="$(normalize_menu_choice "$choice")"
    choice="$(map_menu_shortcut "$choice" "incident")"
    case "$choice" in
      recommended)
        tui_incident_run_recommended "$top_reason" "$top_monitor" "$top_host"
        ;;
      focused_run)
        tui_run_cmd "linux-maint run --only preflight_check,health_monitor,service_monitor,network_monitor --strict" \
          "$0" run --only preflight_check,health_monitor,service_monitor,network_monitor --strict
        ;;
      status_reasons)
        tui_run_cmd "linux-maint status --reasons 10 --table" "$0" status --reasons 10 --table
        ;;
      doctor)
        tui_run_cmd "linux-maint doctor" "$0" doctor
        ;;
      bundle)
        tui_pack_logs_wizard || true
        ;;
      short_report)
        tui_run_cmd "linux-maint report --short --no-trend" "$0" report --short --no-trend
        ;;
      back)
        break
        ;;
    esac
    if [[ "${TUI_RETURN_TO_MAIN:-0}" == "1" ]]; then
      break
    fi
  done
}

run_menu_config(){
  while true; do
    local choice
    TUI_SHORTCUT_CONTEXT="config"
    choice="$(tui_menu_prompt_safe "Config and inventory" \
      config "Inspect: effective config [c]" \
      monitors "Inspect: monitor inventory and requirements [m]" \
      settings "Adjust: menu preferences and defaults [s]" \
      back "Back to main menu [b]")"
    local rc=$TUI_MENU_RC
    if [[ $rc -ne 0 || -z "${choice:-}" ]]; then
      break
    fi
    choice="$(normalize_menu_choice "$choice")"
    choice="$(map_menu_shortcut "$choice" "config")"
    case "$choice" in
      config)
        tui_run_cmd "linux-maint config" "$0" config
        ;;
      monitors)
        tui_run_cmd "linux-maint list-monitors" "$0" list-monitors
        ;;
      settings)
        run_menu_settings
        ;;
      back)
        break
        ;;
    esac
    if [[ "${TUI_RETURN_TO_MAIN:-0}" == "1" ]]; then
      break
    fi
  done
}

tui_incident_recommendation_summary(){
  local reason="${1:-}" monitor="${2:-}" host="${3:-}"
  case "$(tui_incident_recommendation_key "$reason" "$monitor")" in
    connectivity) printf 'connectivity triage: reason explain + focused status + network rerun' ;;
    config) printf 'config remediation: init/config review + doctor + check' ;;
    service) printf 'service recovery: focused status + logs + service rerun' ;;
    patching) printf 'patch follow-up: impacted hosts + rerun after updates' ;;
    runtime) printf 'runtime triage: slow monitors + doctor + timeout review' ;;
    *) printf 'general triage: reasons + doctor + support bundle if needed' ;;
  esac
}

tui_incident_run_recommended(){
  local reason="${1:-}" monitor="${2:-}" host="${3:-}"
  local key
  key="$(tui_incident_recommendation_key "$reason" "$monitor")"
  case "$key" in
    connectivity)
      [[ -n "$reason" ]] && tui_run_cmd "linux-maint explain reason $reason" "$0" explain reason "$reason"
      if [[ -n "$host" ]]; then
        tui_run_cmd "linux-maint status --host $host --problems 20 --table" "$0" status --host "$host" --problems 20 --table
      else
        tui_run_cmd "linux-maint status --reasons 10" "$0" status --reasons 10
      fi
      tui_run_cmd "linux-maint run --only network_monitor --strict" "$0" run --only network_monitor --strict
      ;;
    config)
      [[ -n "$reason" ]] && tui_run_cmd "linux-maint explain reason $reason" "$0" explain reason "$reason"
      tui_run_cmd "linux-maint config --sources" "$0" config --sources
      tui_run_cmd "linux-maint doctor" "$0" doctor
      tui_run_cmd "linux-maint check" "$0" check
      ;;
    service)
      if [[ -n "$host" ]]; then
        tui_run_cmd "linux-maint status --host $host --monitor service --problems 20 --table" "$0" status --host "$host" --monitor service --problems 20 --table
      else
        tui_run_cmd "linux-maint status --monitor service --problems 20 --table" "$0" status --monitor service --problems 20 --table
      fi
      tui_run_cmd "linux-maint logs 200" "$0" logs 200
      tui_run_cmd "linux-maint run --only service_monitor --strict" "$0" run --only service_monitor --strict
      ;;
    patching)
      tui_run_cmd "linux-maint status --reasons 10" "$0" status --reasons 10
      tui_run_cmd "linux-maint report --short --no-trend" "$0" report --short --no-trend
      ;;
    runtime)
      tui_run_cmd "linux-maint runtimes --last 10" "$0" runtimes --last 10
      tui_run_cmd "linux-maint doctor" "$0" doctor
      ;;
    *)
      tui_run_cmd "linux-maint status --reasons 10" "$0" status --reasons 10
      tui_run_cmd "linux-maint doctor" "$0" doctor
      ;;
  esac
}

run_menu_overview(){
  while true; do
    local choice
    TUI_SHORTCUT_CONTEXT="overview"
    choice="$(tui_menu_prompt_safe "Overview" \
      dashboard "Open: live operations dashboard [d]" \
      status "Open: current status snapshot [s]" \
      problems "Review: latest non-OK rows [p]" \
      report "Review: short operator summary [r]" \
      trend "Analyze: recent trend (last 10 runs) [t]" \
      back "Back to main menu [b]")"
    local rc=$TUI_MENU_RC
    if [[ $rc -ne 0 || -z "${choice:-}" ]]; then
      break
    fi
    choice="$(normalize_menu_choice "$choice")"
    choice="$(map_menu_shortcut "$choice" "overview")"
    case "$choice" in
      dashboard)
        if [[ "$TUI_BACKEND" == "gum" ]]; then
          tui_gum_dashboard
        else
          tui_run_cmd "linux-maint status --table" "$0" status --table
        fi
        ;;
      status)
        if [[ "${LM_TUI_DEFAULT_STATUS_VIEW:-table}" == "compact" ]]; then
          tui_run_cmd "linux-maint status --compact" "$0" status --compact
        else
          tui_run_cmd "linux-maint status --table" "$0" status --table
        fi
        ;;
      problems)
        tui_run_cmd "linux-maint status --table --problems ${LM_TUI_DEFAULT_PROBLEMS:-20}" "$0" status --table --problems "${LM_TUI_DEFAULT_PROBLEMS:-20}"
        ;;
      report)
        tui_run_cmd "linux-maint report --short --no-trend" "$0" report --short --no-trend
        ;;
      trend)
        tui_run_cmd "linux-maint trend --last 10" "$0" trend --last 10
        ;;
      back)
        break
        ;;
    esac
    if [[ "${TUI_RETURN_TO_MAIN:-0}" == "1" ]]; then
      break
    fi
  done
}

run_menu_triage(){
  while true; do
    local choice
    TUI_SHORTCUT_CONTEXT="triage"
    choice="$(tui_menu_prompt_safe "Triage" \
      incident "Guide: incident response workflow [i]" \
      drilldown "Inspect: filtered status drilldown [d]" \
      logs "Inspect: latest wrapper log [l]" \
      reasons "Review: top reason tokens [r]" \
      diff "Review: changes since previous run [x]" \
      check "Validate: config and readiness [c]" \
      doctor "Diagnose: deeper checks and fixes [o] [changes]" \
      focused_run "Run: focused service and network checks [f] [changes]" \
      history "Inspect: recent run history [h]" \
      back "Back to main menu [b]")"
    local rc=$TUI_MENU_RC
    if [[ $rc -ne 0 || -z "${choice:-}" ]]; then
      break
    fi
    choice="$(normalize_menu_choice "$choice")"
    choice="$(map_menu_shortcut "$choice" "triage")"
    case "$choice" in
      incident) run_menu_incident_mode ;;
      drilldown) tui_status_drilldown ;;
      logs) tui_run_cmd "linux-maint logs 200" "$0" logs 200 ;;
      reasons) tui_run_cmd "linux-maint status --reasons 10" "$0" status --reasons 10 ;;
      diff) tui_run_cmd "linux-maint diff" "$0" diff ;;
      check) tui_run_cmd "linux-maint check" "$0" check ;;
      doctor) tui_run_cmd "linux-maint doctor" "$0" doctor ;;
      focused_run)
        tui_run_cmd "linux-maint run --only preflight_check,health_monitor,service_monitor,network_monitor --strict" \
          "$0" run --only preflight_check,health_monitor,service_monitor,network_monitor --strict
        ;;
      history) tui_run_cmd "linux-maint history --table" "$0" history --table ;;
      back) break ;;
    esac
    if [[ "${TUI_RETURN_TO_MAIN:-0}" == "1" ]]; then
      break
    fi
  done
}

run_menu_share(){
  while true; do
    local choice
    TUI_SHORTCUT_CONTEXT="share"
    choice="$(tui_menu_prompt_safe "Share" \
      report "Share: short report summary [r]" \
      export_json "Export: unified snapshot JSON [e]" \
      pack_logs "Bundle: guided support package [p] [changes]" \
      trend "Review: recent trend (last 10 runs) [t]" \
      runtimes "Review: runtime summary (last 10 runs) [u]" \
      metrics_prom "Export: Prometheus metrics [m]" \
      quickref "Read: quick command reference [h]" \
      troubleshooting "Read: troubleshooting guide [g]" \
      config "Inspect: effective config [c]" \
      settings "Adjust: menu preferences [s]" \
      about "Inspect: version and project details [a]" \
      back "Back to main menu [b]")"
    local rc=$TUI_MENU_RC
    if [[ $rc -ne 0 || -z "${choice:-}" ]]; then
      break
    fi
    choice="$(normalize_menu_choice "$choice")"
    choice="$(map_menu_shortcut "$choice" "share")"
    case "$choice" in
      report) tui_run_cmd "linux-maint report --short --no-trend" "$0" report --short --no-trend ;;
      export_json) tui_run_cmd "linux-maint export --json" "$0" export --json ;;
      pack_logs) tui_pack_logs_wizard || true ;;
      trend) tui_run_cmd "linux-maint trend --last 10" "$0" trend --last 10 ;;
      runtimes) tui_run_cmd "linux-maint runtimes --last 10" "$0" runtimes --last 10 ;;
      metrics_prom) tui_run_cmd "linux-maint metrics --prom" "$0" metrics --prom ;;
      quickref) tui_view_file "Quick reference" "$(find_doc_file QUICK_REFERENCE.md)" ;;
      troubleshooting) tui_view_file "Troubleshooting" "$(find_doc_file troubleshooting.md)" ;;
      config) tui_run_cmd "linux-maint config" "$0" config ;;
      settings) run_menu_settings ;;
      about) tui_about ;;
      back) break ;;
    esac
    if [[ "${TUI_RETURN_TO_MAIN:-0}" == "1" ]]; then
      break
    fi
  done
}

run_help_block(){
  local usage_line="$1" purpose="$2" when_to_use="${3:-}" key_flags="${4:-}" examples="${5:-}" exit_behavior="${6:-}" repo_note="${7:-}"
  printf 'Usage: %s\n\n' "$usage_line"
  printf 'Purpose:\n  %s\n' "$purpose"
  if [[ -n "$when_to_use" ]]; then
    printf '\nWhen to use:\n'
    printf '%b\n' "$when_to_use"
  fi
  if [[ -n "$key_flags" ]]; then
    printf '\nKey flags:\n'
    printf '%b\n' "$key_flags"
  fi
  if [[ -n "$exit_behavior" ]]; then
    printf '\nExit behavior:\n'
    printf '%b\n' "$exit_behavior"
  fi
  if [[ -n "$repo_note" ]]; then
    printf '\nRepo vs installed:\n'
    printf '%b\n' "$repo_note"
  fi
  if [[ -n "$examples" ]]; then
    printf '\nExamples:\n'
    printf '%b\n' "$examples"
  fi
}

run_menu_investigate(){
  while true; do
    local choice
    TUI_SHORTCUT_CONTEXT="investigate"
    choice="$(tui_menu_prompt_safe "Investigate" \
      drilldown "Analyze: filtered status drilldown [d]" \
      diff "Inspect: changes since previous run [f]" \
      history "Inspect: recent run history [h]" \
      logs "Inspect: latest wrapper log [l]" \
      reasons "Review: top reason tokens [r]" \
      runtimes "Analyze: slowest monitors [u]" \
      back "Back to main menu [b]")"
    local rc=$TUI_MENU_RC
    if [[ $rc -ne 0 || -z "${choice:-}" ]]; then
      break
    fi
    choice="$(normalize_menu_choice "$choice")"
    choice="$(map_menu_shortcut "$choice" "investigate")"
    case "$choice" in
      drilldown) tui_status_drilldown ;;
      diff) tui_run_cmd "linux-maint diff" "$0" diff ;;
      history) tui_run_cmd "linux-maint history --table" "$0" history --table ;;
      logs) tui_run_cmd "linux-maint logs 200" "$0" logs 200 ;;
      reasons) tui_run_cmd "linux-maint status --reasons 10" "$0" status --reasons 10 ;;
      runtimes) tui_run_cmd "linux-maint runtimes --last 10" "$0" runtimes --last 10 ;;
      back) break ;;
    esac
    if [[ "${TUI_RETURN_TO_MAIN:-0}" == "1" ]]; then
      break
    fi
  done
}

run_menu_repair(){
  while true; do
    local choice
    TUI_SHORTCUT_CONTEXT="repair"
    choice="$(tui_menu_prompt_safe "Repair" \
      incident "Guide: incident response workflow [i]" \
      focused_run "Execute: focused service and network checks [f]" \
      check "Validate: config and readiness checks [c]" \
      doctor "Diagnose: doctor checks and fixes [d] [changes]" \
      selfcheck "Validate: self-check (safe) [s]" \
      secprofile "Inspect: strict security profile [p]" \
      back "Back to main menu [b]")"
    local rc=$TUI_MENU_RC
    if [[ $rc -ne 0 || -z "${choice:-}" ]]; then
      break
    fi
    choice="$(normalize_menu_choice "$choice")"
    choice="$(map_menu_shortcut "$choice" "repair")"
    case "$choice" in
      incident) run_menu_incident_mode ;;
      focused_run)
        tui_run_cmd "linux-maint run --only preflight_check,health_monitor,service_monitor,network_monitor --strict" \
          "$0" run --only preflight_check,health_monitor,service_monitor,network_monitor --strict
        ;;
      check) tui_run_cmd "linux-maint check" "$0" check ;;
      doctor) tui_run_cmd "linux-maint doctor" "$0" doctor ;;
      selfcheck) tui_run_cmd "linux-maint self-check" "$0" self-check ;;
      secprofile) tui_run_cmd "linux-maint security-profile --strict" "$0" security-profile --strict ;;
      back) break ;;
    esac
    if [[ "${TUI_RETURN_TO_MAIN:-0}" == "1" ]]; then
      break
    fi
  done
}

run_menu_export(){
  while true; do
    local choice
    TUI_SHORTCUT_CONTEXT="export"
    choice="$(tui_menu_prompt_safe "Export" \
      report "Open: short report summary [r]" \
      trend "Open: recent trend (last 10 runs) [t]" \
      runtimes "Open: runtime summary (last 10 runs) [u]" \
      metrics_prom "Export: Prometheus metrics [m]" \
      metrics_json "Export: metrics JSON [j]" \
      export_json "Export: unified snapshot JSON [e]" \
      pack_logs "Support: guided support bundle wizard [p] [changes]" \
      back "Back to main menu [b]")"
    local rc=$TUI_MENU_RC
    if [[ $rc -ne 0 || -z "${choice:-}" ]]; then
      break
    fi
    choice="$(normalize_menu_choice "$choice")"
    choice="$(map_menu_shortcut "$choice" "export")"
    case "$choice" in
      report) tui_run_cmd "linux-maint report --short --no-trend" "$0" report --short --no-trend ;;
      trend) tui_run_cmd "linux-maint trend --last 10" "$0" trend --last 10 ;;
      runtimes) tui_run_cmd "linux-maint runtimes --last 10" "$0" runtimes --last 10 ;;
      metrics_prom) tui_run_cmd "linux-maint metrics --prom" "$0" metrics --prom ;;
      metrics_json) tui_run_cmd "linux-maint metrics --json" "$0" metrics --json ;;
      export_json) tui_run_cmd "linux-maint export --json" "$0" export --json ;;
      pack_logs)
        tui_pack_logs_wizard || true
        ;;
      back) break ;;
    esac
    if [[ "${TUI_RETURN_TO_MAIN:-0}" == "1" ]]; then
      break
    fi
  done
}

run_menu_docs(){
  while true; do
    local choice
    TUI_SHORTCUT_CONTEXT="docs"
    choice="$(tui_menu_prompt_safe "Docs" \
      quickref "Open: quick command reference [h]" \
      troubleshooting "Open: troubleshooting guide [t]" \
      faq "Open: FAQ and operator tips [f]" \
      reasons "Open: reason token catalog [r]" \
      monitors "Open: monitor matrix and purpose [m]" \
      explain_reason "Explain: one reason token [e]" \
      explain_monitor "Explain: one monitor [o]" \
      explain_status "Explain: status meanings [w]" \
      config "Inspect: effective config [c]" \
      settings "Adjust: menu preferences and defaults [s]" \
      about "Inspect: version and project details [a]" \
      back "Back to main menu [b]")"
    local rc=$TUI_MENU_RC
    if [[ $rc -ne 0 || -z "${choice:-}" ]]; then
      break
    fi
    choice="$(normalize_menu_choice "$choice")"
    choice="$(map_menu_shortcut "$choice" "docs")"
    case "$choice" in
      quickref) tui_view_file "Quick reference" "$(find_doc_file QUICK_REFERENCE.md)" ;;
      troubleshooting) tui_view_file "Troubleshooting" "$(find_doc_file troubleshooting.md)" ;;
      faq) tui_view_file "FAQ" "$(find_doc_file FAQ.md)" ;;
      reasons) tui_view_file "Reasons" "$(find_doc_file REASONS.md)" ;;
      monitors) tui_view_file "Monitors matrix" "$(find_doc_file MONITORS_MATRIX.md)" ;;
      explain_reason)
        local token
        tui_input_capture "Reason token" "e.g. disk_full"
        token="$TUI_INPUT_VALUE"
        if [[ "$TUI_INPUT_RC" -eq 0 && -n "$token" ]]; then
          tui_run_cmd "linux-maint explain reason $token" "$0" explain reason "$token"
        fi
        ;;
      explain_monitor)
        local mon
        tui_input_capture "Monitor name" "e.g. service_monitor"
        mon="$TUI_INPUT_VALUE"
        if [[ "$TUI_INPUT_RC" -eq 0 && -n "$mon" ]]; then
          tui_run_cmd "linux-maint explain monitor $mon" "$0" explain monitor "$mon"
        fi
        ;;
      explain_status)
        local s
        s="$(tui_menu_prompt_safe "Pick status" \
          OK "Healthy" \
          WARN "Warning" \
          CRIT "Critical" \
          UNKNOWN "Unknown" \
          SKIP "Skipped" \
          back "Back")"
        if [[ "$TUI_MENU_RC" -eq 0 && -n "$s" ]]; then
          s="$(normalize_menu_choice "$s")"
          if [[ "$s" != "back" ]]; then
            tui_run_cmd "linux-maint explain status $s" "$0" explain status "$s"
          fi
        fi
        ;;
      config) tui_run_cmd "linux-maint config" "$0" config ;;
      settings) run_menu_settings ;;
      about) tui_about ;;
      back) break ;;
    esac
    if [[ "${TUI_RETURN_TO_MAIN:-0}" == "1" ]]; then
      break
    fi
  done
}

run_menu(){
  if ! [[ -t 1 && -t 2 ]]; then
    echo "ERROR: linux-maint menu requires an interactive TTY" >&2
    exit 1
  fi

  TUI_BACKEND="$(detect_tui_backend || true)"
  if [[ -z "$TUI_BACKEND" ]]; then
    echo "ERROR: install gum, dialog, or whiptail to use linux-maint menu" >&2
    exit 1
  fi

  TUI_TITLE="linux-maint menu"
  TUI_BACKTITLE="Linux Maint ToolKit"

  if [[ "$MODE" == "installed" && $EUID -ne 0 ]]; then
    tui_msgbox $'Some run and repair actions require root in installed mode.\nRe-run with: sudo linux-maint menu'
  fi

  TUI_ANIM_TICK=0
  load_menu_settings
  : "${LM_TUI_DEFAULT_STATUS_VIEW:=table}"
  : "${LM_TUI_DEFAULT_PROBLEMS:=20}"
  : "${LM_TUI_DEFAULT_REASONS:=5}"
  : "${LM_TUI_PREVIEW:=1}"
  : "${LM_TUI_SHORTCUTS:=1}"
  : "${LM_TUI_COMPACT:=0}"
  : "${LM_TUI_LOW_COLOR:=0}"
  : "${LM_TUI_CONFIRM_RISKY:=1}"
  normalize_menu_settings
  TUI_RETURN_TO_MAIN=0
  while true; do
    if tui_bool_enabled "${LM_TUI_COMPACT:-0}"; then
      TUI_MENU_STYLE="compact"
    else
      TUI_MENU_STYLE="full"
    fi
    TUI_SHORTCUT_CONTEXT="main"
    choice="$(tui_menu_prompt_safe "Choose your next step" \
      quickstart "Start here: first setup, guided rescue, and escalation [q]" \
      overview "See fleet health, latest problems, and the fast answer [o]" \
      run "Run checks, preview scope, and launch safely [r]" \
      triage "Investigate failures and repair safely [t]" \
      share "Share reports, bundles, and reference docs [s]" \
      exit "Exit [x]")"
    rc=$TUI_MENU_RC
    if [[ $rc -ne 0 || -z "${choice:-}" ]]; then
      break
    fi
    choice="$(normalize_menu_choice "$choice")"
    choice="$(map_menu_shortcut "$choice" "main")"
    case "$choice" in
      quickstart)
        run_menu_quickstart
        ;;
      overview)
        run_menu_overview
        ;;
      run)
        run_menu_run
        ;;
      triage)
        run_menu_triage
        ;;
      share)
        run_menu_share
        ;;
      exit)
        break
        ;;
    esac
    TUI_RETURN_TO_MAIN=0
    if [[ "$TUI_BACKEND" == "gum" ]]; then
      TUI_ANIM_TICK=$(( (TUI_ANIM_TICK + 1) % 3 ))
    fi
  done

  if [[ "$TUI_BACKEND" == "dialog" ]]; then
    clear
  fi
}
