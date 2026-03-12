# shellcheck shell=bash

HELP_POLICY_EVAL_WORD="eval"

usage(){
  cat <<EOF
Usage: linux-maint <command> [args]

${C_CYAN}Start here${C_RESET}:
  (repo mode; git checkout)
  linux-maint init
  linux-maint run
  linux-maint status

  (installed mode; after install.sh)
  sudo linux-maint init
  sudo linux-maint run
  sudo linux-maint status

${C_CYAN}Most-used operator paths${C_RESET}:
  menu                   Interactive operations console (Quickstart / Overview / Run / Triage / Share)
  run [flags]            Execute the wrapper, scope runs, or preview a plan
  status [flags]         Read the current fleet state and top problems
  report [flags]         One-screen operator summary with trend and runtime context
  check [--json]         Validate config + readiness and show expected skips
  doctor [flags]         Diagnose paths, dependencies, and repair guidance

${C_CYAN}Investigate / export${C_RESET}:
  summary                One-line summary for cron and dashboards
  trend [flags]          Severity and reason trend rollups
  runtimes [flags]       Slowest monitors and runtime history
  export --json|--csv|--jsonl  Export unified artifacts for other systems
  history [flags]        Recent runs from the run index
  run-index [flags]      Inspect or prune the run index
  logs [n]               Tail the latest wrapper log (default n=200)
  diff [--json]          Changes since the previous run
  metrics --json|--prom  Machine metrics snapshot (JSON or Prometheus)

${C_CYAN}Automation / integrations${C_RESET}:
  gate --policy FILE     Evaluate policy thresholds for CI or deploy gates
  plugin <subcommand>    Manage local plugins and provenance checks
  notify [flags]         Send test notifications (webhook/slack/teams/email)
  ticket [flags]         Create Jira or ServiceNow payloads
  cm-hook [flags]        Trigger config-management hooks (ansible/puppet/salt)
  audit-log [flags]      Inspect append-only audit events
  serve [flags]          Local REST API (status/report/metrics/history)
  agent [flags]          Optional loop runner for scheduled checks
  policy <subcommand>    Policy-as-code helpers (init/lint/${HELP_POLICY_EVAL_WORD})
  federate [flags]       Aggregate multiple status JSON snapshots
  ai-assist [flags]      Local heuristic diagnosis assistant
  predict [flags]        Predictive risk summary from history

${C_CYAN}Setup / maintenance${C_RESET}:
  init [flags]           Install config templates into <cfg_dir>
  config [flags]         Show effective config (merged from <cfg_dir>)
  tune dark-site         Apply recommended dark-site defaults to linux-maint.conf
  baseline <...> [flags] Capture or preview baselines
  preflight              Run preflight checks
  validate               Validate config file formats (best-effort)
  check                  Run config_validate + preflight + show expected skips
  deps                   Print required/optional dependency manifest by monitor
  verify-install         Verify install layout, writable paths, and service wiring
  pack-logs [flags]      Create a support bundle tar.gz (logs, config redacted, meta)

${C_CYAN}Release / packaging${C_RESET}:
  version [flags]        Print installed version/build metadata
  make-tarball           Build offline release tarball (repo / release tree only)
  verify-release         Verify release tarball integrity
  upgrade <tarball>      Verify, install, and record rollback metadata
  install [args]         Install from a checkout or extracted release tree
  uninstall [args]       Uninstall files installed by install.sh

${C_CYAN}Help / reference${C_RESET}:
  help [command]          Show help for a command (shortcut for usage)
  explain reason <token>  Explain a reason= token (from docs/REASONS.md)
  explain monitor <name>  Explain a monitor (purpose, deps, common reasons)
  explain status <S>      Explain a status value (OK/WARN/CRIT/UNKNOWN/SKIP)
  help                    Show this help

${C_CYAN}Environment${C_RESET}:
  LM_PROGRESS=0         disable progress bar during run
  NO_COLOR=1            disable colored output
  LM_LOCAL_ONLY=true    force local-only mode (CI/testing)
  LM_DARK_SITE=true     enable conservative offline defaults
  LM_TUI_BACKEND=gum    force menu UI backend (gum|dialog|whiptail)
  LM_TUI_COMPACT=1      compact menu style (no full banner mode)
  LM_TUI_LOW_COLOR=1    low-color menu mode
  LM_TUI_CONFIRM_RISKY=0 disable risky-action confirmations

${C_CYAN}Examples by task${C_RESET}:
  Inspect current state: linux-maint status --only WARN --reasons 5
  Review a short summary: linux-maint report --short --no-trend
  Plan safely first:      NO_COLOR=1 linux-maint run --local-only --plan --json
  Run focused checks:     linux-maint run --only service_monitor,ntp_drift_monitor
  Compare runs:           linux-maint diff
  Export machine data:    NO_COLOR=1 linux-maint trend --last 10 --json
  Create support bundle:  linux-maint pack-logs --out /tmp --redact
  Inspect monitor list:   linux-maint list-monitors
  Validate summary file:  linux-maint lint-summary <summary.log>
  Work from the menu:     linux-maint menu

${C_CYAN}Best next commands${C_RESET}:
  See docs/README.md for full docs and flag details
  linux-maint help <command>
  NO_COLOR=1 linux-maint report
EOF
}

command_usage(){
  local c="${1:-}"
  case "$c" in
    ""|help|-h|--help)
      usage; return 0;;
    run)
      run_help_block \
        "linux-maint run [flags]" \
        "Execute checks across the resolved scope, or preview the exact plan without running it." \
        "  - full fleet or group runs\n  - focused monitor reruns\n  - safe plan previews before execution\n  - resume an interrupted run from history" \
        "  --group G              use <cfg_dir>/hosts.d/G.txt\n  --hosts a,b            ad-hoc host list\n  --exclude a,b          exclude hosts\n  --tag TAG[,TAG]        filter hosts by inventory_meta.csv tags\n  --role ROLE            filter hosts by inventory_meta.csv role\n  --env ENV              filter hosts by inventory_meta.csv environment\n  --parallel N           max parallel SSH\n  --local-only           run checks locally only\n  --ssh-opts \"...\"       override SSH options\n  --retry N              SSH retries per host (maps to LM_SSH_RETRY)\n  --host-timeout N       SSH timeout seconds (maps to LM_SSH_TIMEOUT)\n  --only a,b             run only selected monitors (names with/without _monitor)\n  --skip a,b             skip selected monitors\n  --strategy S           execution strategy: fail-soft|fail-fast|quorum\n  --quorum-percent N     quorum success percent for --strategy quorum\n  --respect-maintenance  skip execution outside configured maintenance window\n  --drain-file PATH      hosts drain file to exclude from runs\n  --plan                 show resolved hosts/monitors without executing\n  --json                 with --plan, emit JSON\n  --dry-run              alias for --plan\n  --strict               fail if any monitor emits malformed summary lines\n  --resume RUN_ID        resume an interrupted run_id (or use 'latest')\n                         requires a matching valid run_state_<run_id>.log\n  --allow-concurrent     allow overlapping runs (skip lock)\n  --lock-timeout N       wait up to N seconds for run lock (default: 60)\n  --progress|--no-progress  progress bar control\n  Inventory metadata file:\n    ${LM_INVENTORY_META:-<cfg_dir>/inventory_meta.csv}\n    columns: host,tags,role,env    tags may use ; or | separators\n  Optional privilege policy file:\n    ${LM_MONITOR_PRIV_POLICY_FILE:-<cfg_dir>/monitor_privilege_policy.conf}\n    lines: monitor=requires_root|allow_sudo|no_sudo" \
        "  linux-maint run --group prod --parallel 10 --progress\n  linux-maint run --tag web --env prod --plan --json\n  linux-maint run --role db --only service_monitor,ntp_drift_monitor\n  linux-maint run --skip inventory_export,backup_check\n  linux-maint run --strategy quorum --quorum-percent 80\n  linux-maint run --retry 2 --host-timeout 10\n  linux-maint run --resume latest\n  linux-maint run --lock-timeout 120\n  NO_COLOR=1 linux-maint run --local-only --plan\n  NO_COLOR=1 linux-maint run --local-only --plan --json" \
        "  - rc=0 when execution or plan completes without non-OK wrapper failure\n  - rc reflects the wrapper result for real runs\n  - rc=2 for flag or plan contract errors" \
        "  - repo mode reads repo-local defaults unless overridden\n  - installed mode typically targets /etc/linux_maint and system-owned paths"
      ;;
    menu)
      run_help_block \
        "linux-maint menu" \
        "Open the interactive operations console for guided setup, health checks, triage, and handoff." \
        "  - day-to-day operator workflow\n  - first setup and safe first run\n  - current-incident triage\n  - handoff, export, and escalation flow" \
        "  Main sections:\n    Quickstart    first setup, guided rescue, and escalation workflows\n    Overview      fleet health, latest problems, and the fast answer\n    Run           execute checks, preview plans, or use the run wizard\n    Triage        investigate failures and repair safely\n    Share         report, export, bundle, and reference docs in one place\n  Best path by task:\n    First day with the tool?       Quickstart -> first setup\n    Need the current answer fast?  Overview -> status or report\n    Need to understand a failure?  Triage -> drilldown or logs\n    Need to recover quickly?       Triage -> incident or doctor\n    Need to share data?            Share -> report, export JSON, or pack logs\n  Quickstart shortcuts:\n    inventory      edit servers.txt directly from the Quickstart menu\n    groups         open the hosts.d group overview directly from Quickstart\n    docs           open quick reference and troubleshooting from Quickstart\n  Quickstart bootstrap:\n    first_setup guides init, config review, check, plan, and starter baselines\n    current_incident is best after you have a summary or wrapper log\n    escalation is best after report/JSON/log artifacts exist\n  Workflow notes:\n    Triage keeps drilldown, logs, doctor, and focused recovery in one workspace\n    Share keeps report/export tasks close to quick reference and troubleshooting docs\n  Global gum controls:\n    arrows         move through the chooser\n    Enter          open the highlighted action\n    Search         smart command palette (search by names, aliases, task words)\n                   examples: first run, triage, bundle, report, logs, doctor\n    Preview        open action previews for the current menu\n    Help           reopen quick controls for the current menu\n    Esc            go back\n    Optional letter shortcuts remain available when enabled\n  Useful env vars:\n    LM_TUI_BACKEND=gum|dialog|whiptail\n    LM_TUI_DASH_REFRESH=<seconds>\n    LM_TUI_DEFAULT_STATUS_VIEW=table|compact\n    LM_TUI_DEFAULT_PROBLEMS=<1..100>\n    LM_TUI_DEFAULT_REASONS=<0..20>\n    LM_TUI_PREVIEW=1|0\n    LM_TUI_SHORTCUTS=1|0\n    LM_TUI_COMPACT=1|0\n    LM_TUI_LOW_COLOR=1|0\n    LM_TUI_CONFIRM_RISKY=1|0" \
        "  linux-maint menu\n  LM_TUI_BACKEND=gum linux-maint menu\n  LM_TUI_COMPACT=1 linux-maint menu" \
        "  - returns non-zero if no supported TUI backend is available\n  - returns non-zero when interactive TTY requirements are not met" \
        "  repo mode:      linux-maint menu\n  installed mode: sudo linux-maint menu"
      ;;
    list-monitors)
      echo "Usage: linux-maint list-monitors [--json]";;
    lint-summary)
      echo "Usage: linux-maint lint-summary <summary_or_log_file> [--json]";;
    status)
      run_help_block \
        "linux-maint status [flags]" \
        "Read the latest run artifacts and present the current fleet state." \
        "  - quick human check after a run\n  - filtered drilldown by host, monitor, or status\n  - machine-readable status export" \
        "  Filters:\n    --only OK|WARN|CRIT|UNKNOWN|SKIP\n    --host PATTERN            filter by host\n    --monitor PATTERN         filter by monitor\n    --match-mode contains|exact|regex\n    --since 15m|2h|1d|30s     recent artifacts only\n  Output:\n    --summary                 one-line summary\n    --json                    machine JSON\n    --prom                    Prometheus textfile format\n    --output PATH             write output atomically to PATH\n    --table                   table output\n    --group-by host|monitor|reason\n    --top N                   limit group-by rows (requires --group-by)\n    --problems N              cap problem list (max 100)\n    --reasons N               top reasons rollup (max 20)\n    --strict                  fail if summary lines are malformed" \
        "  linux-maint status --compact\n  linux-maint status --reasons 5\n  linux-maint status --host web --monitor service --only WARN\n  linux-maint status --json" \
        "  - rc follows status severity handling for strict or machine-facing modes\n  - rc=2 for invalid flags or malformed upstream artifacts in strict paths"
      ;;
    report)
      run_help_block \
        "linux-maint report [flags]" \
        "Build a unified operator report from status, trend, and runtime artifacts." \
        "  - short handoff summary\n  - copy/paste output for tickets or incidents\n  - structured JSON export for automation" \
        "  --short         one-screen summary\n  --compact       minimal output\n  --table         table formatting\n  --json          machine JSON\n  --redact        redact secrets in human output only\n  --output PATH   write output atomically to PATH\n  --no-trend      suppress trend section\n  --no-slow       suppress slow monitors\n  --no-reasons    suppress reason rollup\n  --no-problems   suppress problem list" \
        "  linux-maint report --short --no-trend\n  NO_COLOR=1 linux-maint report --compact\n  linux-maint report --json" \
        "  - rc=2 when delegated status data is unavailable or invalid for machine-facing paths"
      ;;
    metrics)
      run_help_block \
        "linux-maint metrics --json|--prom [--output PATH]" \
        "Export the latest fleet metrics for dashboards, alerting, or automation." \
        "  - Prometheus scraping\n  - machine-readable metrics handoff\n  - quick inspection of fleet totals from the CLI" \
        "  --json         machine JSON payload\n  --prom         Prometheus text format\n  --output PATH  write output atomically to PATH" \
        "  linux-maint metrics --prom\n  linux-maint metrics --json\n  linux-maint metrics --prom --output /tmp/linux-maint.prom" \
        "  - rc=2 when delegated status data is unavailable or invalid\n  - choose exactly one output mode"
      ;;
    config)
      run_help_block \
        "linux-maint config [--json] [--sources] [--lint] [--diff-defaults]" \
        "Read the effective merged configuration from the active config root." \
        "  - confirm effective values before a run\n  - check config source order\n  - lint config without executing checks" \
        "  --json           machine-readable output\n  --sources        show source file order in human output\n  --lint           parse and validate config files only\n  --diff-defaults  show values that differ from built-in defaults" \
        "  linux-maint config\n  linux-maint config --sources\n  linux-maint config --lint\n  linux-maint config --json" \
        "  - rc=2 for structured config errors such as source failure or invalid types" \
        "  - repo mode: repo-local fallback config (or LM_CFG_DIR)\n  - installed mode: /etc/linux_maint unless overridden\n  - read-only command; unreadable files are reported as config errors"
      ;;
    doctor)
      run_help_block \
        "linux-maint doctor [--json] [--compact] [--fix] [--fix-deps] [--fix-deps-optional] [--yes] [--dry-run]" \
        "Inspect layout, writable paths, dependencies, and readiness, with optional repair actions." \
        "  - investigate missing paths or permissions\n  - confirm dependencies before production use\n  - repair layout issues in installed mode" \
        "  Read-only mode:\n    default              inspect layout, config, writable paths, and dependencies\n    --compact            shorter human summary\n    --json               machine-readable output\n  Fix mode:\n    --fix                repair directories and permissions\n    --fix-deps           also try to install required dependencies\n    --fix-deps-optional  also try to install optional dependencies\n    --dry-run            preview fix actions only\n    --yes                skip interactive confirmation" \
        "  linux-maint doctor\n  linux-maint doctor --compact\n  linux-maint doctor --json\n  sudo linux-maint doctor --fix --yes" \
        "  - non-zero when critical readiness checks fail\n  - fix mode may modify system state and usually requires root" \
        "  - In repo mode, doctor targets repo-local paths\n  - In installed mode, read-only doctor works without sudo; fix modes still require elevated access for system paths"
      ;;
    self-check)
      run_help_block \
        "linux-maint self-check [--json] [--compact] [--strict]" \
        "Run a lightweight sanity check over the current operator environment." \
        "  - quick confidence check before deeper runs\n  - CI or local smoke validation" \
        "  --json      machine-readable output\n  --compact   shorter human summary\n  --strict    fail on warnings that are advisory by default" \
        "  linux-maint self-check\n  linux-maint self-check --strict\n  linux-maint self-check --json" ;;
    security-profile)
      run_help_block \
        "linux-maint security-profile [--json] [--strict]" \
        "Inspect security-sensitive configuration, permissions, and policy posture." \
        "  - verify secure defaults after setup\n  - audit operator posture before rollout" \
        "  --json      machine-readable output\n  --strict    raise the bar for advisory findings" \
        "  linux-maint security-profile\n  linux-maint security-profile --strict\n  linux-maint security-profile --json" ;;
    check)
      run_help_block \
        "linux-maint check [--json]" \
        "Run config validation and readiness checks as the safest operator preflight." \
        "  - before the first run\n  - after config changes\n  - before escalation to a full fleet execution" \
        "  Runs:\n    1. config_validate\n    2. preflight\n    3. expected-skip summary\n  --json      automation-safe output" \
        "  linux-maint check\n  linux-maint check --json" \
        "  - Exit code follows the highest underlying severity.\n  - rc=2 for invalid delegated status/config paths in machine-facing flows\n  - read-only command; installed mode does not require sudo unless the underlying files do"
      ;;
    gate)
      echo "Usage: linux-maint gate --policy <file> [--json]";;
    plugin)
      cat <<'EOF'
Usage: linux-maint plugin <subcommand> [flags]

Subcommands:
  list [--json]
  search [--index FILE] [--json] [--strict]
  lint-index [--index FILE] [--json] [--strict]
  verify-index [--index FILE] [--json] [--strict]
  provenance-report [--index FILE] [--out FILE] [--json] [--strict]
  init <name> [--out DIR]
  install <source_dir> [--name NAME] [--force]
  update <name> [--source DIR] [--index FILE] [--force]
  verify <name> [--json]
  remove <name>
EOF
      ;;
    notify)
      run_help_block \
        "linux-maint notify --provider <webhook|slack|teams|email|pagerduty> [flags]" \
        "Send a test notification through the configured delivery channel." \
        "  - verify notification wiring before a real incident\n  - preview provider payloads safely\n  - test webhook and ticketing handoff plumbing" \
        "  --provider P\n  --url URL            required for webhook/slack/teams\n  --to ADDR            required for email\n  --routing-key KEY    required for pagerduty\n  --severity S         pagerduty severity (critical|error|warning|info; default: warning)\n  --source TEXT        pagerduty source (default: linux-maint)\n  --subject TEXT       optional (email default: linux-maint notification)\n  --message TEXT       message body (default: linux-maint test notification)\n  --dry-run            print payload only (no send)" \
        "  linux-maint notify --provider webhook --url https://example.invalid/hook --dry-run\n  linux-maint notify --provider pagerduty --routing-key KEY --severity critical --dry-run"
      ;;
    ticket)
      run_help_block \
        "linux-maint ticket --provider <jira|servicenow> --url URL --title TEXT --body TEXT [flags]" \
        "Build or submit a ticket payload for the supported ITSM providers." \
        "  - validate ticket shape before automation consumes it\n  - generate a human handoff payload from the CLI\n  - smoke-test integration fields" \
        "  --provider P\n  --url URL\n  --title TEXT\n  --body TEXT\n  --project KEY        required for jira (default: OPS)\n  --issue-type TYPE    jira issue type (default: Task)\n  --json               machine JSON output\n  --dry-run            print payload only (no send)" \
        "  linux-maint ticket --provider jira --url https://jira.example --title test --body body --dry-run\n  linux-maint ticket --provider servicenow --url https://snow.example --title test --body body --json --dry-run"
      ;;
    audit-log)
      run_help_block \
        "linux-maint audit-log [--last N] [--json] [--verify]" \
        "Inspect or verify the append-only audit log used for high-value command traces." \
        "  - review recent automation hooks\n  - verify chain integrity after sensitive actions\n  - export machine-readable audit history" \
        "  --last N    number of events to show (default 20)\n  --json      machine-readable output\n  --verify    verify the audit chain before printing events" \
        "  linux-maint audit-log --last 20\n  linux-maint audit-log --verify\n  linux-maint audit-log --json"
      ;;
    cm-hook)
      run_help_block \
        "linux-maint cm-hook --provider <ansible|puppet|salt> [flags]" \
        "Trigger a configuration-management hook from the toolkit surface." \
        "  - bridge a finding into existing config-management tooling\n  - test provider commands before live use\n  - emit machine-readable hook results" \
        "  --provider P\n  --target HOSTS        comma-separated target hosts (default: localhost)\n  --playbook PATH       ansible playbook path (ansible only)\n  --module NAME         ansible module (default: ping)\n  --args TEXT           module/action args\n  --json                machine JSON output\n  --dry-run             print command only (no execution)" \
        "  linux-maint cm-hook --provider ansible --playbook site.yml --dry-run\n  linux-maint cm-hook --provider salt --target web-1,web-2 --args 'test.ping' --json --dry-run"
      ;;
    serve)
      run_help_block \
        "linux-maint serve [--host 127.0.0.1] [--port 9910]" \
        "Expose the local status/report/metrics/history surfaces over a lightweight HTTP server." \
        "  - local dashboard integrations\n  - smoke-test API consumers\n  - temporary read-only sharing from the current node" \
        "  --host ADDR   bind host (default 127.0.0.1)\n  --port N      bind port (default 9910)\n  Env:\n    LM_SERVE_CMD_TIMEOUT=<seconds>   max delegated command runtime (default 15)" \
        "  linux-maint serve\n  linux-maint serve --host 0.0.0.0 --port 9910" \
        "  - exits non-zero if the server cannot bind or delegated JSON contracts fail"
      ;;
    agent)
      run_help_block \
        "linux-maint agent [--once] [--interval N] [--max-runs N] [--dry-run]" \
        "Run the toolkit in a lightweight loop for scheduled or embedded use." \
        "  - test a periodic run loop locally\n  - embed linux-maint in simple host-side automation\n  - run once for wrapper-compatible delegation" \
        "  --once         execute one run only\n  --interval N   loop interval in seconds (must be >0)\n  --max-runs N   stop after N iterations\n  --dry-run      print delegated command only" \
        "  linux-maint agent --once\n  linux-maint agent --interval 300 --max-runs 12\n  linux-maint agent --dry-run" \
        "  - finite runs preserve delegated run failures\n  - rc=2 for invalid interval or option combinations"
      ;;
    policy)
      run_help_block \
        "linux-maint policy <init|lint|${HELP_POLICY_EVAL_WORD}> ..." \
        "Create, validate, and evaluate policy-as-code checks against linux-maint output." \
        "  - bootstrap a policy file\n  - lint policy before CI/deploy use\n  - evaluate policy thresholds against status artifacts" \
        "  init FLAGS:\n    --out FILE          write starter policy\n  lint FLAGS:\n    --policy FILE       policy file to validate\n    --json              machine-readable lint output\n  ${HELP_POLICY_EVAL_WORD} FLAGS:\n    --policy FILE       policy file to evaluate\n    --json              machine-readable evaluation output" \
        "  linux-maint policy init --out policy.json\n  linux-maint policy lint --policy policy.json\n  linux-maint policy ${HELP_POLICY_EVAL_WORD} --policy policy.json --json" \
        "  - rc=2 for invalid policy shape or invalid evaluation inputs"
      ;;
    federate)
      run_help_block \
        "linux-maint federate --input file1,file2[,fileN] [--json]" \
        "Aggregate multiple status snapshots into a single fleet-of-fleets view." \
        "  - combine site or cluster snapshots\n  - validate handoff data before upstream aggregation\n  - export a merged machine-readable status view" \
        "  --input FILES  comma-separated status --json files\n  --json         machine-readable federated output" \
        "  linux-maint federate --input a.json,b.json\n  linux-maint federate --input site1.json,site2.json --json" \
        "  - rc=2 if any input is unreadable, invalid JSON, or not a valid status snapshot"
      ;;
    ai-assist)
      run_help_block \
        "linux-maint ai-assist [--json]" \
        "Generate a local heuristic diagnosis summary from the latest status data." \
        "  - quick operator hinting after a failing run\n  - machine-readable diagnosis output for wrappers\n  - local-only analysis without external services" \
        "  --json   machine-readable diagnosis payload" \
        "  linux-maint ai-assist\n  linux-maint ai-assist --json" \
        "  - rc=2 when delegated status JSON is missing, unsuccessful, or invalid"
      ;;
    predict)
      run_help_block \
        "linux-maint predict [--last N] [--json]" \
        "Estimate near-term risk from recent run history." \
        "  - spot worsening recent behavior\n  - feed lightweight risk signals into automation\n  - summarize history trends without full manual review" \
        "  --last N   number of recent runs to inspect (must be >0)\n  --json      machine-readable output" \
        "  linux-maint predict --last 10\n  linux-maint predict --json" \
        "  - rc=2 for invalid history input or malformed delegated history JSON"
      ;;
    history)
      run_help_block \
        "linux-maint history [flags]" \
        "Read recent run metadata from the run index without parsing full logs." \
        "  - inspect recent run outcomes quickly\n  - feed automation from run history\n  - compare the latest run against prior activity" \
        "  --last N      number of runs (default 10)\n  --json        machine JSON\n  --table       table output\n  --compact     one-line latest run\n  --sqlite      read from sqlite history index (or set LM_HISTORY_SQLITE=1)" \
        "  linux-maint history --last 10\n  linux-maint history --table\n  linux-maint history --json" \
        "  - rc=2 when the run index is corrupt or unreadable for machine-facing paths" \
        "  - repo mode reads repo-local state unless LM_RUN_INDEX_FILE overrides it\n  - installed mode reads the installed state dir by default without requiring sudo for read-only access"
      ;;
    run-index)
      run_help_block \
        "linux-maint run-index [flags]" \
        "Inspect and maintain the lightweight run index used by history and trend features." \
        "  - check index size and freshness\n  - prune retained entries safely\n  - export machine-readable index stats" \
        "  --stats      show run index stats (default)\n  --prune      prune to last N entries (default keep=200)\n  --keep N     number of entries to retain\n  --json       machine JSON" \
        "  linux-maint run-index --stats\n  linux-maint run-index --prune --keep 200\n  linux-maint run-index --json" \
        "  - rc=2 if prune cannot rewrite the index safely\n  - installed mode stats/json are read-only; --prune still requires root"
      ;;
    summary)
      echo "Usage: linux-maint summary [--no-color]";;
    trend)
      run_help_block \
        "linux-maint trend [--last N] [--since DATE] [--until DATE] [--json|--csv|--export csv|json] [--redact] [--output PATH]" \
        "Roll up severity and reason movement across recent runs." \
        "  - spot worsening monitors or reasons\n  - hand off recent change context\n  - export trend data to dashboards" \
        "  --last N           number of runs to analyze\n  --since DATE       lower time bound\n  --until DATE       upper time bound\n  --json|--csv       machine-friendly export\n  --export csv|json  explicit export mode\n  --redact           redact exported content\n  --output PATH      write output atomically to PATH\n  Anomaly options:\n    --anomaly           enable anomaly detection against recent baseline\n    --anomaly-z N       z-score threshold (default: 2.0)\n    --anomaly-window N  baseline run window size (default: 5, min: 2)" \
        "  linux-maint trend --last 10\n  linux-maint trend --last 20 --anomaly --anomaly-window 7\n  NO_COLOR=1 linux-maint trend --last 10 --json" \
        "  - rc=2 on invalid export combinations or broken backing artifacts"
      ;;
    runtimes)
      run_help_block \
        "linux-maint runtimes [--last N] [--json]" \
        "Show slowest monitors and recent runtime history." \
        "  - identify monitors that need timeout or threshold tuning\n  - compare run cost over time" \
        "  --last N    number of runs to inspect\n  --json      machine-readable output" \
        "  linux-maint runtimes --last 10\n  linux-maint runtimes --json" ;;
    export)
      run_help_block \
        "linux-maint export --json|--csv|--jsonl" \
        "Export unified status artifacts for people or downstream systems." \
        "  - generate a single JSON snapshot\n  - hand off CSV or JSONL rows to other tools\n  - package the latest summary data cleanly" \
        "  --json     unified JSON payload\n  --csv      summary rows as CSV\n  --jsonl    summary rows as JSONL" \
        "  linux-maint export --json\n  linux-maint export --csv\n  linux-maint export --jsonl" \
        "  - rc=2 when preferred summary JSON exists but is corrupt"
        ;;
    init)
      run_help_block \
        "linux-maint init [--minimal] [--force]" \
        "Install config templates into the active config root." \
        "  - first setup in repo mode or installed mode\n  - refresh starter templates after upgrade" \
        "  --minimal   install only the core starter files\n  --force     overwrite existing templates" \
        "  linux-maint init\n  linux-maint init --minimal\n  linux-maint init --force" \
        "" \
        "  - repo mode initializes the repo-local config root without sudo\n  - installed mode usually needs sudo for system paths" ;;
    tune)
      echo "Usage: linux-maint tune dark-site";;
    baseline)
      cat <<'EOF'
Usage: linux-maint baseline <status|ports|configs|users|sudoers> [flags]

  status        show baseline freshness and latest drift state
  --json        with status, emit machine-readable output
  --stale-days N  mark baselines stale after N days (default 30)
  --update      write baseline
  --diff        show changes vs baseline
  --show        print baseline contents
  --local-only  no SSH
  --progress|--no-progress

Notes:
  - status is read-only in repo mode and installed mode.
  - In installed mode, --show and --diff are read-only.
  - Capture/update paths still require write access to the active config root.
EOF
      ;;
    preflight)
      echo "Usage: linux-maint preflight";;
    validate)
      echo "Usage: linux-maint validate";;
    deps)
      echo "Usage: linux-maint deps";;
    verify-install)
      run_help_block \
        "linux-maint verify-install" \
        "Verify the expected layout, writable paths, and best-effort service wiring without mutating state." \
        "  - confirm the binary, wrapper, helpers, and support libs are present\n  - inspect writable runtime paths after install or upgrade\n  - review best-effort systemd/timer visibility" \
        "" \
        "  linux-maint verify-install\n  sudo linux-maint verify-install" \
        "  - non-zero when required layout checks fail" \
        "  - repo mode verifies repo-local defaults and writable paths\n  - installed mode verifies installed layout, writable runtime dirs, and service wiring\n  - run with sudo in installed mode if you want writable path checks to pass cleanly" ;;
    pack-logs)
      run_help_block \
        "linux-maint pack-logs [flags]" \
        "Create a support bundle with logs, config context, and optional encryption." \
        "  - escalate an incident to another team\n  - capture artifacts before cleanup or remediation\n  - export an offline-friendly support package" \
        "  --out DIR             output directory\n  --redact|--no-redact  redact sensitive log/state data\n  --progress|--no-progress\n  --hash                include SHA256 manifest\n  --gpg                 encrypt bundle (requires --gpg-recipient)\n  --gpg-recipient ID    GPG recipient (email or key id)\n  --gpg-keep-plaintext  keep the .tar.gz alongside the .gpg\n  Bundle meta always includes:\n    meta/bundle_meta.txt\n    meta/bundle_manifest.txt\n    meta/redaction_report.txt\n    meta/support_handoff.txt" \
        "  linux-maint pack-logs --out /tmp --redact\n  linux-maint pack-logs --out /tmp --hash\n  linux-maint pack-logs --out /tmp --gpg --gpg-recipient ops@example.com" \
        "  - non-zero if packaging, hashing, or encryption prerequisites fail\n  - preflight validation prevents leaving unintended plaintext output behind"
      ;;
    version)
      run_help_block \
        "linux-maint version [--short|--json]" \
        "Print installed version/build metadata from BUILD_INFO." \
        "  - confirm the installed release after upgrade or reinstall\n  - capture build metadata in tickets or support bundles\n  - feed automation with machine-readable metadata when needed" \
        "  --short   compact one-line version summary\n  --json    machine-readable version/build metadata" \
        "  linux-maint version\n  linux-maint version --short\n  linux-maint version --json" \
        "  - non-zero if BUILD_INFO is missing" \
        "  - installed mode reads <prefix>/share/linux_maint/BUILD_INFO\n  - repo mode still reports from the active share path when present" ;;
    make-tarball)
      echo "Usage: linux-maint make-tarball";;
    verify-release)
      echo "Usage: linux-maint verify-release <tarball> --sums <SHA256SUMS>";;
    upgrade)
      run_help_block \
        "linux-maint upgrade <tarball> [flags]" \
        "Upgrade an installed node from a verified release tarball and record rollback metadata." \
        "  - inspect a release before touching the node\n  - snapshot config and installed payload inventory before changing files\n  - leave a manifest with rollback guidance under the active state dir" \
        "  --check                  inspect the tarball only; no install, no root required\n  --json                   with --check, emit machine-readable assessment\n  --sums FILE              checksum file for verify-release\n  --sig FILE               detached signature for verify-release\n  --rollback-tarball FILE  known-good rollback artifact to record\n  --with-user              pass through to install.sh\n  --with-timer             pass through to install.sh\n  --with-logrotate         pass through to install.sh\n  --dry-run                verify and snapshot only\n  --keep-workdir           keep the extracted workdir for inspection" \
        "  linux-maint upgrade ./Linux_Maint_ToolKit-v0.3.7-<sha>.tgz --check --sums ./SHA256SUMS\n  linux-maint upgrade ./Linux_Maint_ToolKit-v0.3.7-<sha>.tgz --check --json --sums ./SHA256SUMS\n  sudo linux-maint upgrade /tmp/Linux_Maint_ToolKit-v0.3.7-<sha>.tgz --sums /tmp/SHA256SUMS --rollback-tarball /srv/releases/Linux_Maint_ToolKit-v0.3.6-<sha>.tgz\n  sudo linux-maint upgrade ./Linux_Maint_ToolKit-v0.3.7-<sha>.tgz --sums ./SHA256SUMS --with-timer --with-logrotate" \
        "  - --check highlights current vs target version, release notes, and operator warnings\n  - non-zero if verify-release, install.sh, or post-upgrade verify-install fails\n  - installed mode only; repo checkouts should run install.sh directly from the extracted tree" ;;
    install)
      run_help_block \
        "linux-maint install [args]" \
        "Run install.sh from a checkout or extracted release tree." \
        "  - install or refresh an existing node from local sources\n  - forward install.sh flags without retyping the script path" \
        "  any extra args are passed through to install.sh" \
        "  sudo linux-maint install\n  sudo linux-maint install --with-user --with-timer --with-logrotate" \
        "  - non-zero if install.sh fails" \
        "  - repo mode and extracted release trees are supported\n  - installed mode cannot reinstall itself without local source tree access" ;;
    uninstall)
      run_help_block \
        "linux-maint uninstall [args]" \
        "Run install.sh --uninstall from a checkout or extracted release tree." \
        "  - remove files previously installed by install.sh\n  - forward uninstall-related flags without retyping the script path" \
        "  any extra args are passed through to install.sh --uninstall" \
        "  sudo linux-maint uninstall" \
        "  - non-zero if uninstall fails" \
        "  - repo mode and extracted release trees are supported\n  - installed mode cannot uninstall itself without local source tree access" ;;
    diff)
      run_help_block \
        "linux-maint diff [--json]" \
        "Show changes between the latest and previous summary snapshots." \
        "  - confirm what changed after remediation or deployment\n  - feed automation with summary deltas\n  - spot new or cleared findings quickly" \
        "  --json   machine-readable diff payload" \
        "  linux-maint diff\n  NO_COLOR=1 linux-maint diff --json"
      ;;
    logs)
      run_help_block \
        "linux-maint logs [n]" \
        "Tail the latest wrapper log for fast CLI-side evidence review." \
        "  - inspect recent failures without opening the full file\n  - verify a just-finished run\n  - copy recent evidence into handoff notes" \
        "  n   number of lines to print (default 200)" \
        "  linux-maint logs\n  linux-maint logs 400"
      ;;
    explain)
      run_help_block \
        "linux-maint explain <reason|status|monitor> ..." \
        "Explain a reason token, status value, or monitor name from the toolkit vocabulary." \
        "  - decode findings quickly during triage\n  - understand monitor purpose and dependencies\n  - look up built-in status meanings" \
        "  reason <token>   explain a reason token\n  status <S>      explain OK/WARN/CRIT/UNKNOWN/SKIP\n  monitor <name>  explain monitor purpose and common reasons" \
        "  linux-maint explain reason ssh_unreachable\n  linux-maint explain status WARN\n  linux-maint explain monitor service_monitor"
      ;;
    *)
      echo "Unknown command: $c" >&2
      usage
      return 2;;
  esac
}
