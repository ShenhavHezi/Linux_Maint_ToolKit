#!/usr/bin/env bash
# Plugin and advanced command helpers for linux-maint.

plugin_root_dir(){
  if [[ -n "${LM_PLUGIN_DIR:-}" ]]; then
    printf '%s' "$LM_PLUGIN_DIR"
  elif [[ "$MODE" == "repo" ]]; then
    printf '%s/plugins' "$REPO_ROOT"
  else
    printf '%s' "/var/lib/linux_maint/plugins"
  fi
}

plugin_index_default_path(){
  if [[ -n "${LM_PLUGIN_INDEX:-}" ]]; then
    printf '%s' "$LM_PLUGIN_INDEX"
  elif [[ "$MODE" == "repo" ]]; then
    printf '%s/plugins/index.json' "$REPO_ROOT"
  elif [[ -f "$SHARE/plugins/index.json" ]]; then
    printf '%s/plugins/index.json' "$SHARE"
  else
    printf '%s/plugins/index.json' "$SHARE"
  fi
}

linux_maint_version_file(){
  if [[ -n "${LM_VERSION_FILE:-}" ]]; then
    printf '%s' "$LM_VERSION_FILE"
  elif [[ "$MODE" == "repo" ]]; then
    printf '%s/VERSION' "$REPO_ROOT"
  elif [[ -f "$SHARE/VERSION" ]]; then
    printf '%s/VERSION' "$SHARE"
  else
    printf '%s/VERSION' "$REPO_ROOT"
  fi
}

plugin_registry_file(){
  local root
  root="$(plugin_root_dir)"
  printf '%s/registry.json' "$root"
}

plugin_name_is_valid() {
  [[ "${1:-}" =~ ^[A-Za-z0-9._-]+$ ]]
}

plugin_validate_name_or_die() {
  local name="${1:-}" context="${2:-plugin name}"
  if ! plugin_name_is_valid "$name"; then
    echo "ERROR: invalid plugin name for $context: $name" >&2
    echo "Plugin names must match [A-Za-z0-9._-]+" >&2
    exit 2
  fi
}

linux_maint_cmd_plugin() {
    if [[ "$MODE" == "repo" ]]; then
      export LM_CFG_DIR="${LM_CFG_DIR:-$REPO_ROOT/.etc_linux_maint}"
    fi
    sub="${1:-}"
    shift || true
    case "$sub" in
      list)
        PLUG_JSON=0
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --json) PLUG_JSON=1; shift 1;;
            -h|--help) command_usage plugin; exit 0;;
            *) echo "Unknown plugin list flag: $1" >&2; exit 2;;
          esac
        done
        plug_root="$(plugin_root_dir)"
        reg_file="$(plugin_registry_file)"
        python3 - "$plug_root" "$reg_file" "$PLUG_JSON" <<'PY'
import json, os, sys
root, reg_file, json_mode = sys.argv[1:4]
json_mode = json_mode == "1"
plugins = []
registry_error = ""
if os.path.exists(reg_file):
    try:
        with open(reg_file, "r", encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, dict):
            registry_error = "registry must be object"
        else:
            plugins = data.get("plugins") or []
            if not isinstance(plugins, list):
                registry_error = "registry plugins must be list"
                plugins = []
    except Exception as e:
        registry_error = f"invalid registry: {e}"
if json_mode:
    out = {"plugin_contract_version": 1, "root": root, "plugins": plugins}
    if registry_error:
        out["ok"] = False
        out["error"] = registry_error
    print(json.dumps(out, indent=2, sort_keys=True))
    raise SystemExit(0 if not registry_error else 2)
if registry_error:
    print(f"ERROR: plugin registry is invalid: {reg_file}: {registry_error}", file=sys.stderr)
    raise SystemExit(2)
print("=== linux-maint plugin list ===")
print(f"root={root}")
if not plugins:
    print("no plugins installed")
    raise SystemExit(0)
w = max(len(str(p.get("name",""))) for p in plugins)
print(f"{'NAME':<{w}} VERSION SOURCE")
for p in plugins:
    print(f"{p.get('name',''):<{w}} {p.get('version','-')} {p.get('source','-')}")
PY
        ;;

      search)
        PLUG_JSON=0
        PLUG_STRICT=0
        idx_file="$(plugin_index_default_path)"
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --json) PLUG_JSON=1; shift 1;;
            --strict) PLUG_STRICT=1; shift 1;;
            --index) idx_file="$2"; shift 2;;
            -h|--help) command_usage plugin; exit 0;;
            *) echo "Unknown plugin search flag: $1" >&2; exit 2;;
          esac
        done
        python3 - "$idx_file" "$PLUG_JSON" "$PLUG_STRICT" <<'PY'
import hashlib, json, os, re, shutil, subprocess, sys
idx, json_mode, strict = sys.argv[1:4]
json_mode = json_mode == "1"
strict = strict == "1"
plugins = []
errors = []
attestation = None
policy = None
policy_path = os.environ.get("LM_PLUGIN_TRUST_POLICY_FILE", "").strip()
if not policy_path:
    cfg_dir = os.environ.get("LM_CFG_DIR", "/etc/linux_maint")
    policy_path = os.path.join(cfg_dir, "plugin_trust_policy.json")
allowed_trust = {"official", "verified", "community", "experimental", "untrusted"}
if os.path.exists(idx):
    try:
        with open(idx, "r", encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict):
            plugins = data.get("plugins") or []
            attestation = data.get("attestation")
        elif isinstance(data, list):
            plugins = data
    except Exception:
        errors.append("invalid_json")
        plugins = []
else:
    errors.append("index_missing")

if os.path.exists(policy_path):
    try:
        with open(policy_path, "r", encoding="utf-8") as f:
            policy = json.load(f)
        if not isinstance(policy, dict):
            errors.append("trust_policy: must be object")
            policy = {}
    except Exception:
        errors.append("trust_policy: invalid_json")
        policy = {}
else:
    policy = {}

def validate_entry(i, p):
    if not isinstance(p, dict):
        errors.append(f"plugins[{i}]: must be object")
        return
    name = str(p.get("name", "")).strip()
    ver = str(p.get("version", "")).strip()
    src = str(p.get("source", "")).strip()
    if not name:
        errors.append(f"plugins[{i}]: missing name")
    elif not re.match(r"^[A-Za-z0-9._-]+$", name):
        errors.append(f"plugins[{i}]: invalid name")
    if not ver:
        errors.append(f"plugins[{i}]: missing version")
    if not src:
        errors.append(f"plugins[{i}]: missing source")
    trust = str(p.get("trust", "")).strip()
    if trust and trust not in allowed_trust:
        errors.append(f"plugins[{i}]: invalid trust '{trust}'")
    comp = p.get("compatibility")
    if comp is not None and not isinstance(comp, dict):
        errors.append(f"plugins[{i}]: compatibility must be object")
    sig = p.get("signature")
    if sig is not None:
        if not isinstance(sig, dict):
            errors.append(f"plugins[{i}]: signature must be object")
        else:
            st = str(sig.get("type", "")).strip()
            sv = str(sig.get("value", "")).strip()
            tg = sig.get("target", None)
            sf = sig.get("file", None)
            sk = sig.get("key", None)
            if st and st not in ("none", "sha256", "gpg", "cosign"):
                errors.append(f"plugins[{i}]: unsupported signature.type '{st}'")
            if st in ("sha256", "gpg", "cosign") and not sv:
                errors.append(f"plugins[{i}]: signature.value required when signature.type is set")
            if tg is not None and not isinstance(tg, str):
                errors.append(f"plugins[{i}]: signature.target must be string when provided")
            if sf is not None and not isinstance(sf, str):
                errors.append(f"plugins[{i}]: signature.file must be string when provided")
            if sk is not None and not isinstance(sk, str):
                errors.append(f"plugins[{i}]: signature.key must be string when provided")

for i, p in enumerate(plugins):
    validate_entry(i, p)

def verify_attestation(att, index_path):
    out = {
        "present": False,
        "type": "",
        "verified": False,
        "issues": []
    }
    if att is None:
        out["issues"].append("attestation_missing")
        return out
    out["present"] = True
    if not isinstance(att, dict):
        out["issues"].append("attestation must be object")
        return out
    st = str(att.get("type", "")).strip()
    out["type"] = st
    if st not in ("none", "sha256", "gpg", "cosign"):
        out["issues"].append(f"unsupported attestation.type '{st}'")
        return out
    if st == "none":
        out["verified"] = True
        return out

    index_dir = os.path.dirname(os.path.abspath(index_path))
    target_rel = str(att.get("target", "plugins.json") or "plugins.json").strip()
    target_path = os.path.join(index_dir, target_rel)
    if not os.path.isfile(target_path):
        out["issues"].append(f"attestation target not found: {target_rel}")
        return out

    if st == "sha256":
        expected = str(att.get("value", "")).strip().lower()
        if not expected:
            out["issues"].append("attestation.value required for sha256")
            return out
        try:
            h = hashlib.sha256()
            with open(target_path, "rb") as f:
                for chunk in iter(lambda: f.read(65536), b""):
                    h.update(chunk)
            actual = h.hexdigest().lower()
            if actual != expected:
                out["issues"].append(f"attestation sha256 mismatch: expected={expected} actual={actual}")
                return out
            out["verified"] = True
            out["digest"] = actual
            return out
        except Exception as e:
            out["issues"].append(f"attestation sha256 verification failed: {e}")
            return out

    sig_default = f"{target_rel}.asc" if st == "gpg" else f"{target_rel}.sig"
    sig_rel = str(att.get("file", sig_default) or sig_default).strip()
    sig_path = os.path.join(index_dir, sig_rel)
    if not os.path.isfile(sig_path):
        out["issues"].append(f"attestation signature file not found: {sig_rel}")
        return out

    if st == "gpg":
        if shutil.which("gpg") is None:
            out["issues"].append("gpg command not found for attestation verification")
            return out
        proc = subprocess.run(
            ["gpg", "--status-fd", "1", "--verify", sig_path, target_path],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            universal_newlines=True,
        )
        if proc.returncode != 0:
            out["issues"].append(f"gpg attestation verification failed for {target_rel}")
            return out
        signer = ""
        for line in (proc.stdout or "").splitlines():
            if "VALIDSIG " in line:
                parts = line.split()
                if "VALIDSIG" in parts:
                    i = parts.index("VALIDSIG")
                    if i + 1 < len(parts):
                        signer = parts[i + 1].strip()
                        break
        if signer:
            out["signer_fingerprint"] = signer
        out["verified"] = True
        return out

    key_rel = str(att.get("key", "") or "").strip()
    key_path = os.path.join(index_dir, key_rel) if key_rel else ""
    if not key_path or not os.path.isfile(key_path):
        out["issues"].append("attestation key file missing for cosign (set attestation.key)")
        return out
    try:
        h = hashlib.sha256()
        with open(key_path, "rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                h.update(chunk)
        out["key_sha256"] = h.hexdigest().lower()
    except Exception as e:
        out["issues"].append(f"cosign key hash failed: {e}")
        return out
    if shutil.which("cosign") is None:
        out["issues"].append("cosign command not found for attestation verification")
        return out
    proc = subprocess.run(
        ["cosign", "verify-blob", "--signature", sig_path, "--key", key_path, target_path],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    if proc.returncode != 0:
        out["issues"].append(f"cosign attestation verification failed for {target_rel}")
        return out
    out["verified"] = True
    return out

att = verify_attestation(attestation, idx)
require_attest = os.environ.get("LM_PLUGIN_REQUIRE_ATTEST", "0").lower() in ("1", "true", "yes")
require_policy = os.environ.get("LM_PLUGIN_REQUIRE_TRUST_POLICY", "0").lower() in ("1", "true", "yes")
policy_applied = False
if strict and require_policy and not os.path.exists(policy_path):
    errors.append(f"trust_policy required by LM_PLUGIN_REQUIRE_TRUST_POLICY but missing: {policy_path}")

def as_set(v):
    if isinstance(v, list):
        return {str(x).strip().lower() for x in v if str(x).strip()}
    return set()

if strict and att.get("present") and att.get("verified"):
    if not isinstance(policy, dict):
        policy = {}
    st = str(att.get("type", "")).strip()
    sec = policy.get(st, {})
    if sec is None:
        sec = {}
    if not isinstance(sec, dict):
        errors.append(f"trust_policy: section '{st}' must be object")
        sec = {}
    policy_applied = bool(sec)
    if st == "sha256":
        digest = str(att.get("digest", "")).strip().lower()
        trusted = as_set(sec.get("trusted_digests"))
        revoked = as_set(sec.get("revoked_digests"))
        if digest and digest in revoked:
            errors.append(f"attestation: digest revoked by trust policy: {digest}")
        if trusted and digest not in trusted:
            errors.append("attestation: digest not present in trust policy trusted_digests")
    elif st == "gpg":
        fp = str(att.get("signer_fingerprint", "")).strip().lower()
        trusted = as_set(sec.get("trusted_fingerprints"))
        revoked = as_set(sec.get("revoked_fingerprints"))
        if fp and fp in revoked:
            errors.append(f"attestation: signer fingerprint revoked by trust policy: {fp}")
        if trusted and fp not in trusted:
            errors.append("attestation: signer fingerprint not present in trust policy trusted_fingerprints")
    elif st == "cosign":
        key_hash = str(att.get("key_sha256", "")).strip().lower()
        trusted = as_set(sec.get("trusted_key_sha256"))
        revoked = as_set(sec.get("revoked_key_sha256"))
        if key_hash and key_hash in revoked:
            errors.append(f"attestation: cosign key hash revoked by trust policy: {key_hash}")
        if trusted and key_hash not in trusted:
            errors.append("attestation: cosign key hash not present in trust policy trusted_key_sha256")

if strict and require_attest and not att.get("present"):
    errors.append("attestation required by LM_PLUGIN_REQUIRE_ATTEST but missing")
if strict and att.get("present") and not att.get("verified"):
    for issue in att.get("issues") or []:
        errors.append(f"attestation: {issue}")

ok = len(errors) == 0
if json_mode:
    print(json.dumps({
        "plugin_contract_version": 1,
        "index": idx,
        "strict": strict,
        "attestation": att,
        "require_attestation": require_attest,
        "trust_policy_file": policy_path,
        "require_trust_policy": require_policy,
        "trust_policy_applied": policy_applied,
        "ok": ok,
        "errors": errors,
        "plugins": plugins
    }, indent=2, sort_keys=True))
    raise SystemExit(0 if (ok or not strict) else 2)
print("=== linux-maint plugin search ===")
print(f"index={idx}")
print(f"attestation={att.get('type') or 'none'} verified={att.get('verified')}")
print(f"trust_policy_file={policy_path}")
print(f"trust_policy_applied={str(policy_applied).lower()}")
if errors:
    print("index_validation=FAIL")
    for e in errors[:20]:
        print(f"- {e}")
    if strict:
        raise SystemExit(2)
else:
    print("index_validation=OK")
if not plugins:
    print("no plugins found")
    raise SystemExit(0)
w = max(len(str(p.get("name",""))) for p in plugins)
print(f"{'NAME':<{w}} VERSION TRUST DESCRIPTION")
for p in plugins:
    print(f"{p.get('name',''):<{w}} {p.get('version','-')} {p.get('trust','-')} {p.get('description','-')}")
PY
        ;;

      lint-index)
        PLUG_JSON=0
        PLUG_STRICT=0
        idx_file="$(plugin_index_default_path)"
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --json) PLUG_JSON=1; shift 1;;
            --strict) PLUG_STRICT=1; shift 1;;
            --index) idx_file="$2"; shift 2;;
            -h|--help) command_usage plugin; exit 0;;
            *) echo "Unknown plugin lint-index flag: $1" >&2; exit 2;;
          esac
        done
        args=(plugin search --index "$idx_file")
        [[ "$PLUG_JSON" -eq 1 ]] && args+=(--json)
        [[ "$PLUG_STRICT" -eq 1 ]] && args+=(--strict)
        exec "$0" "${args[@]}"
        ;;

      verify-index)
        PLUG_JSON=0
        PLUG_STRICT=0
        idx_file="$(plugin_index_default_path)"
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --json) PLUG_JSON=1; shift 1;;
            --strict) PLUG_STRICT=1; shift 1;;
            --index) idx_file="$2"; shift 2;;
            -h|--help) command_usage plugin; exit 0;;
            *) echo "Unknown plugin verify-index flag: $1" >&2; exit 2;;
          esac
        done
        args=(plugin search --index "$idx_file" --json)
        [[ "$PLUG_STRICT" -eq 1 ]] && args+=(--strict)
        set +e
        out="$("$0" "${args[@]}" 2>/dev/null)"
        rc=$?
        set -e
        if [[ -z "$out" ]]; then
          echo "ERROR: unable to read plugin index: $idx_file" >&2
          exit 2
        fi
        if [[ "$PLUG_JSON" -eq 1 ]]; then
          python3 - "$out" <<'PY'
import json, sys
o = json.loads(sys.argv[1])
a = o.get("attestation") or {}
print(json.dumps({
  "plugin_contract_version": 1,
  "index": o.get("index"),
  "strict": o.get("strict"),
  "ok": bool(o.get("ok", False)),
  "attestation": a,
  "require_attestation": bool(o.get("require_attestation", False)),
  "trust_policy_file": o.get("trust_policy_file"),
  "require_trust_policy": bool(o.get("require_trust_policy", False)),
  "trust_policy_applied": bool(o.get("trust_policy_applied", False)),
  "errors": o.get("errors") or []
}, indent=2, sort_keys=True))
PY
          exit "$rc"
        fi
        python3 - "$out" <<'PY'
import json, sys
o = json.loads(sys.argv[1])
a = o.get("attestation") or {}
print("=== linux-maint plugin verify-index ===")
print(f"index={o.get('index')}")
print(f"strict={o.get('strict')}")
print(f"attestation_type={a.get('type') or 'none'}")
print(f"attestation_present={a.get('present')}")
print(f"attestation_verified={a.get('verified')}")
issues = a.get("issues") or []
if issues:
    for i in issues:
        print(f"- {i}")
errs = o.get("errors") or []
if errs:
    print("errors:")
    for e in errs[:20]:
        print(f"- {e}")
print(f"result={'OK' if o.get('ok') else 'FAIL'}")
PY
        exit "$rc"
        ;;

      provenance-report)
        PLUG_JSON=0
        PLUG_STRICT=0
        idx_file="$(plugin_index_default_path)"
        out_file=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --json) PLUG_JSON=1; shift 1;;
            --strict) PLUG_STRICT=1; shift 1;;
            --index) idx_file="$2"; shift 2;;
            --out) out_file="$2"; shift 2;;
            -h|--help) command_usage plugin; exit 0;;
            *) echo "Unknown plugin provenance-report flag: $1" >&2; exit 2;;
          esac
        done
        tmp_dir="$(mktemp -d)"
        idx_out="$tmp_dir/index.json"
        list_out="$tmp_dir/list.json"
        ver_dir="$tmp_dir/verifies"
        mkdir -p "$ver_dir"

        idx_args=(plugin verify-index --index "$idx_file" --json)
        [[ "$PLUG_STRICT" -eq 1 ]] && idx_args+=(--strict)
        set +e
        "$0" "${idx_args[@]}" > "$idx_out" 2>/dev/null
        idx_rc=$?
        "$0" plugin list --json > "$list_out" 2>/dev/null
        list_rc=$?
        set -e

        python3 - "$list_out" "$ver_dir" "$0" <<'PY'
import json, os, subprocess, sys
list_path, out_dir, cli = sys.argv[1:4]
names = []
if os.path.exists(list_path):
    try:
        with open(list_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        for p in (data.get("plugins") or []):
            if isinstance(p, dict):
                n = str(p.get("name", "")).strip()
                if n:
                    names.append(n)
    except Exception:
        pass
for n in names:
    proc = subprocess.run([cli, "plugin", "verify", n, "--json"], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, universal_newlines=True)
    with open(os.path.join(out_dir, f"{n}.json"), "w", encoding="utf-8") as f:
        f.write(proc.stdout or "")
    with open(os.path.join(out_dir, f"{n}.rc"), "w", encoding="utf-8") as f:
        f.write(str(proc.returncode))
PY

        report_json="$tmp_dir/provenance_report.json"
        python3 - "$idx_out" "$idx_rc" "$list_out" "$list_rc" "$ver_dir" "$idx_file" "$out_file" "$PLUG_STRICT" "$report_json" <<'PY'
import datetime, hashlib, json, os, sys, tempfile
idx_path, idx_rc, list_path, list_rc, ver_dir, idx_file, out_file, strict_mode, out_report = sys.argv[1:10]
idx_rc = int(idx_rc)
list_rc = int(list_rc)
strict_mode = strict_mode == "1"

policy_file = os.environ.get("LM_PLUGIN_TRUST_POLICY_FILE", "").strip()
if not policy_file:
    cfg_dir = os.environ.get("LM_CFG_DIR", "/etc/linux_maint")
    policy_file = os.path.join(cfg_dir, "plugin_trust_policy.json")

policy_sha = ""
if os.path.isfile(policy_file):
    try:
        h = hashlib.sha256()
        with open(policy_file, "rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                h.update(chunk)
        policy_sha = h.hexdigest()
    except Exception:
        policy_sha = ""

index_ver = {}
index_parse_error = False
if os.path.exists(idx_path):
    try:
        with open(idx_path, "r", encoding="utf-8") as f:
            index_ver = json.load(f)
    except Exception:
        index_parse_error = True

names = []
if os.path.exists(list_path):
    try:
        with open(list_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        for p in (data.get("plugins") or []):
            if isinstance(p, dict):
                n = str(p.get("name", "")).strip()
                if n:
                    names.append(n)
    except Exception:
        pass

plugins = []
ok_plugins = 0
for n in names:
    p = {"name": n, "rc": 2, "ok": False, "verify": {}}
    try:
        with open(os.path.join(ver_dir, f"{n}.rc"), "r", encoding="utf-8") as f:
            p["rc"] = int((f.read() or "2").strip())
    except Exception:
        p["rc"] = 2
    try:
        with open(os.path.join(ver_dir, f"{n}.json"), "r", encoding="utf-8") as f:
            payload = json.load(f)
        p["verify"] = payload
        p["ok"] = bool(payload.get("ok", False)) and p["rc"] == 0
    except Exception:
        p["verify"] = {"parse_error": True}
        p["ok"] = False
    if p["ok"]:
        ok_plugins += 1
    plugins.append(p)

index_ok = bool(index_ver.get("ok", False)) and idx_rc == 0 and not index_parse_error
summary = {
    "plugins_total": len(plugins),
    "plugins_ok": ok_plugins,
    "plugins_failed": max(len(plugins) - ok_plugins, 0),
    "index_ok": index_ok
}
overall_ok = summary["index_ok"] and summary["plugins_failed"] == 0 and list_rc == 0

report = {
    "plugin_provenance_contract_version": 1,
    "generated_at_utc": datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z"),
    "index_file": idx_file,
    "strict": strict_mode,
    "policy_file": policy_file,
    "policy_file_exists": os.path.isfile(policy_file),
    "policy_file_sha256": policy_sha,
    "list_rc": list_rc,
    "index_verify_rc": idx_rc,
    "index_parse_error": index_parse_error,
    "index_verification": index_ver,
    "plugins": plugins,
    "summary": summary,
    "overall_ok": overall_ok
}

with open(out_report, "w", encoding="utf-8") as f:
    json.dump(report, f, indent=2, sort_keys=True)

if out_file:
    os.makedirs(os.path.dirname(out_file) or ".", exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".plugin_provenance.", dir=os.path.dirname(out_file) or ".")
    os.close(fd)
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(tmp, out_file)
PY

        if [[ "$PLUG_JSON" -eq 1 ]]; then
          cat "$report_json"
        else
          python3 - "$report_json" "$out_file" <<'PY'
import json, sys
path, out_file = sys.argv[1:3]
o = json.load(open(path, "r", encoding="utf-8"))
s = o.get("summary") or {}
print("=== linux-maint plugin provenance-report ===")
print(f"index_file={o.get('index_file')}")
print(f"policy_file={o.get('policy_file')}")
print(f"policy_file_exists={o.get('policy_file_exists')}")
print(f"index_ok={s.get('index_ok')}")
print(f"plugins_total={s.get('plugins_total')}")
print(f"plugins_ok={s.get('plugins_ok')}")
print(f"plugins_failed={s.get('plugins_failed')}")
print(f"overall_ok={o.get('overall_ok')}")
if out_file:
    print(f"out={out_file}")
PY
        fi
        if [[ "$PLUG_STRICT" -eq 1 ]]; then
          python3 - "$report_json" <<'PY'
import json, sys
o = json.load(open(sys.argv[1], "r", encoding="utf-8"))
raise SystemExit(0 if bool(o.get("overall_ok")) else 2)
PY
          rc=$?
          rm -rf "$tmp_dir"
          exit "$rc"
        fi
        rm -rf "$tmp_dir"
        ;;

      init)
        name="${1:-}"
        shift || true
        [[ -n "$name" ]] || { echo "ERROR: plugin init requires <name>" >&2; exit 2; }
        out_dir="${PWD}"
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --out) out_dir="$2"; shift 2;;
            -h|--help) command_usage plugin; exit 0;;
            *) echo "Unknown plugin init flag: $1" >&2; exit 2;;
          esac
        done
        if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ ]]; then
          echo "ERROR: plugin name must match [a-zA-Z0-9._-]+" >&2
          exit 2
        fi
        mkdir -p "$out_dir"
        target="$out_dir/$name"
        if [[ -e "$target" ]]; then
          echo "ERROR: target already exists: $target" >&2
          exit 2
        fi
        mkdir -p "$target"
        cat > "$target/plugin.json" <<EOF
{
  "name": "$name",
  "version": "0.1.0",
  "description": "TODO: describe plugin",
  "author": "TODO",
  "entrypoint": "README.md"
}
EOF
        cat > "$target/README.md" <<EOF
# $name

Plugin scaffold generated by \`linux-maint plugin init\`.

## Next steps
1. Update \`plugin.json\` metadata.
2. Add plugin assets/scripts to this directory.
3. Install locally:
   \`\`\`bash
   linux-maint plugin install "$target"
   \`\`\`
EOF
        echo "created plugin scaffold: $target"
        ;;

      install)
        src="${1:-}"
        shift || true
        [[ -n "$src" ]] || { echo "ERROR: plugin install requires <source_dir>" >&2; exit 2; }
        pname=""
        force=0
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --name) pname="$2"; shift 2;;
            --force) force=1; shift 1;;
            -h|--help) command_usage plugin; exit 0;;
            *) echo "Unknown plugin install flag: $1" >&2; exit 2;;
          esac
        done
        if [[ ! -d "$src" ]]; then
          echo "ERROR: plugin source directory not found: $src" >&2
          exit 2
        fi
        if [[ -n "$pname" ]]; then
          plugin_validate_name_or_die "$pname" "plugin install --name"
        fi
        if [[ "$MODE" == "installed" ]]; then
          need_root_for plugin
        fi
        plug_root="$(plugin_root_dir)"
        reg_file="$(plugin_registry_file)"
        mkdir -p "$plug_root"
        audit_log_append "plugin-install" "start" "source=$src name=${pname:-auto} root=$plug_root force=$force"
        python3 - "$src" "$plug_root" "$reg_file" "$pname" "$force" <<'PY'
import datetime, json, os, shutil, sys, tempfile
src, root, reg_file, pname, force = sys.argv[1:6]
force = force == "1"
def valid_name(value):
    return bool(value) and all(ch.isalnum() or ch in "._-" for ch in value)
manifest_path = os.path.join(src, "plugin.json")
meta = {"name": os.path.basename(os.path.abspath(src)), "version": "0.0.0", "description": "", "source": src}
if os.path.exists(manifest_path):
    try:
        with open(manifest_path, "r", encoding="utf-8") as f:
            m = json.load(f)
        if isinstance(m, dict):
            meta["name"] = str(m.get("name") or meta["name"])
            meta["version"] = str(m.get("version") or meta["version"])
            meta["description"] = str(m.get("description") or "")
    except Exception:
        pass
if pname:
    meta["name"] = pname
name = meta["name"]
if not valid_name(name):
    print(f"ERROR: invalid plugin name: {name}", file=sys.stderr)
    print("Plugin names must match [A-Za-z0-9._-]+", file=sys.stderr)
    raise SystemExit(2)
dest = os.path.join(root, name)
if os.path.exists(dest) and not force:
    print(f"ERROR: plugin already exists: {name}", file=sys.stderr)
    raise SystemExit(2)
tmp_dest = tempfile.mkdtemp(prefix=".plugin_", dir=root)
tmp_copy = os.path.join(tmp_dest, name)

registry = {"plugins": []}
if os.path.exists(reg_file):
    try:
        with open(reg_file, "r", encoding="utf-8") as f:
            registry = json.load(f)
    except Exception as e:
        print(f"ERROR: invalid plugin registry: {reg_file}: {e}", file=sys.stderr)
        raise SystemExit(2)
    if not isinstance(registry, dict):
        print(f"ERROR: invalid plugin registry shape: {reg_file}", file=sys.stderr)
        raise SystemExit(2)
plugins = registry.get("plugins") or []
if not isinstance(plugins, list):
    print(f"ERROR: invalid plugin registry plugins list: {reg_file}", file=sys.stderr)
    raise SystemExit(2)
plugins = [p for p in plugins if str(p.get("name","")) != name]
meta["installed_at"] = datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")
plugins.append(meta)
registry["plugins"] = sorted(plugins, key=lambda p: str(p.get("name","")))

backup_dir = ""
installed = False
registry_tmp = ""
had_dest = os.path.exists(dest)
try:
    # Copy into a staging directory first so source-side failures do not damage the current install.
    shutil.copytree(src, tmp_copy)
    if had_dest:
        backup_dir = tempfile.mkdtemp(prefix=".plugin_prev_", dir=root)
        os.rmdir(backup_dir)
        os.replace(dest, backup_dir)
    os.replace(tmp_copy, dest)
    installed = True

    os.makedirs(os.path.dirname(reg_file) or ".", exist_ok=True)
    fd, registry_tmp = tempfile.mkstemp(prefix=".plugin_registry.", dir=os.path.dirname(reg_file) or ".")
    os.close(fd)
    with open(registry_tmp, "w", encoding="utf-8") as f:
        json.dump(registry, f, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(registry_tmp, reg_file)
    registry_tmp = ""
except Exception:
    if registry_tmp and os.path.exists(registry_tmp):
        os.unlink(registry_tmp)
    if backup_dir and os.path.exists(backup_dir):
        if os.path.exists(dest):
            shutil.rmtree(dest, ignore_errors=True)
        try:
            os.replace(backup_dir, dest)
        except Exception:
            pass
    elif not had_dest and os.path.exists(dest):
        shutil.rmtree(dest, ignore_errors=True)
    raise
finally:
    shutil.rmtree(tmp_dest, ignore_errors=True)
    if installed and backup_dir and os.path.exists(backup_dir):
        shutil.rmtree(backup_dir, ignore_errors=True)

print(f"installed plugin {name} -> {dest}")
PY
        audit_log_append "plugin-install" "success" "source=$src name=${pname:-auto} root=$plug_root"
        ;;

      update)
        name="${1:-}"
        shift || true
        [[ -n "$name" ]] || { echo "ERROR: plugin update requires <name>" >&2; exit 2; }
        plugin_validate_name_or_die "$name" "plugin update"
        src=""
        idx_file="$(plugin_index_default_path)"
        force=1
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --source) src="$2"; shift 2;;
            --index) idx_file="$2"; shift 2;;
            --force) force=1; shift 1;;
            -h|--help) command_usage plugin; exit 0;;
            *) echo "Unknown plugin update flag: $1" >&2; exit 2;;
          esac
        done
        plug_root="$(plugin_root_dir)"
        reg_file="$(plugin_registry_file)"
        if [[ -z "$src" ]]; then
          src="$(python3 - "$name" "$reg_file" "$idx_file" <<'PY'
import json, os, sys
name, reg_file, idx_file = sys.argv[1:4]
src = ""
if os.path.exists(reg_file):
    try:
        with open(reg_file, "r", encoding="utf-8") as f:
            reg = json.load(f)
        for p in (reg.get("plugins") or []):
            if str(p.get("name","")) == name and str(p.get("source","")).strip():
                src = str(p.get("source","")).strip()
                break
    except Exception:
        pass
if (not src) and os.path.exists(idx_file):
    try:
        with open(idx_file, "r", encoding="utf-8") as f:
            data = json.load(f)
        if isinstance(data, dict):
            lst = data.get("plugins") or []
        elif isinstance(data, list):
            lst = data
        else:
            lst = []
        for p in lst:
            if isinstance(p, dict) and str(p.get("name","")) == name and str(p.get("source","")).strip():
                src = str(p.get("source","")).strip()
                break
    except Exception:
        pass
print(src, end="")
PY
)"
        fi
        [[ -n "$src" ]] || { echo "ERROR: unable to resolve source for plugin '$name' (use --source or --index)" >&2; exit 2; }
        [[ -d "$src" ]] || { echo "ERROR: plugin source directory not found: $src" >&2; exit 2; }
        audit_log_append "plugin-update" "start" "name=$name source=$src index=$idx_file"
        set +e
        "$0" plugin install "$src" --name "$name" --force
        rc=$?
        set -e
        audit_log_append "plugin-update" "$([[ "$rc" -eq 0 ]] && echo success || echo failure)" "name=$name source=$src rc=$rc"
        exit "$rc"
        ;;

      verify)
        name="${1:-}"
        shift || true
        [[ -n "$name" ]] || { echo "ERROR: plugin verify requires <name>" >&2; exit 2; }
        plugin_validate_name_or_die "$name" "plugin verify"
        PLUG_JSON=0
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --json) PLUG_JSON=1; shift 1;;
            -h|--help) command_usage plugin; exit 0;;
            *) echo "Unknown plugin verify flag: $1" >&2; exit 2;;
          esac
        done
        plug_root="$(plugin_root_dir)"
        reg_file="$(plugin_registry_file)"
        version_file="$(linux_maint_version_file)"
        python3 - "$name" "$plug_root" "$reg_file" "$PLUG_JSON" "$version_file" <<'PY'
import hashlib, json, os, shutil, subprocess, sys
name, root, reg_file, json_mode, version_file = sys.argv[1:6]
json_mode = json_mode == "1"
dest = os.path.join(root, name)
exists = os.path.isdir(dest)
manifest = os.path.join(dest, "plugin.json")
manifest_ok = False
meta = {}
issues = []
if os.path.exists(manifest):
    try:
        with open(manifest, "r", encoding="utf-8") as f:
            m = json.load(f)
        if isinstance(m, dict):
            manifest_ok = True
            meta = m
    except Exception:
        manifest_ok = False
registry_has = False
registry_entry = {}
policy_path = os.environ.get("LM_PLUGIN_TRUST_POLICY_FILE", "").strip()
if not policy_path:
    cfg_dir = os.environ.get("LM_CFG_DIR", "/etc/linux_maint")
    policy_path = os.path.join(cfg_dir, "plugin_trust_policy.json")
require_policy = os.environ.get("LM_PLUGIN_REQUIRE_TRUST_POLICY", "0").lower() in ("1", "true", "yes")
policy = {}
policy_applied = False
if os.path.exists(policy_path):
    try:
        with open(policy_path, "r", encoding="utf-8") as f:
            loaded = json.load(f)
        if isinstance(loaded, dict):
            policy = loaded
        else:
            issues.append("trust_policy: must be object")
    except Exception:
        issues.append("trust_policy: invalid_json")
elif require_policy:
    issues.append(f"trust_policy required by LM_PLUGIN_REQUIRE_TRUST_POLICY but missing: {policy_path}")
if os.path.exists(reg_file):
    try:
        with open(reg_file, "r", encoding="utf-8") as f:
            reg = json.load(f)
        if not isinstance(reg, dict):
            issues.append("registry: must be object")
            reg = {"plugins": []}
        for p in (reg.get("plugins") or []):
            if str(p.get("name","")) == name:
                registry_has = True
                registry_entry = p if isinstance(p, dict) else {}
                break
    except Exception as e:
        issues.append(f"registry: invalid_json ({e})")
# Optional compatibility check.
cli_version = ""
if os.path.exists(version_file):
    try:
        cli_version = open(version_file, "r", encoding="utf-8").read().strip()
    except Exception:
        cli_version = ""
compat = meta.get("compatibility") if isinstance(meta, dict) else None
compat_ok = True
if isinstance(compat, dict):
    min_v = str(compat.get("min_cli_version", "")).strip()
    max_v = str(compat.get("max_cli_version", "")).strip()
    if cli_version and min_v and cli_version < min_v:
        compat_ok = False
        issues.append(f"cli_version {cli_version} < min_cli_version {min_v}")
    if cli_version and max_v and cli_version > max_v:
        compat_ok = False
        issues.append(f"cli_version {cli_version} > max_cli_version {max_v}")

trust = str(meta.get("trust") or registry_entry.get("trust") or "").strip()
if trust and trust not in ("official", "verified", "community", "experimental", "untrusted"):
    issues.append(f"invalid trust '{trust}'")

sig = meta.get("signature")
signature_ok = True
sig_type = ""
sig_digest = ""
signer_fingerprint = ""
cosign_key_sha256 = ""
if sig is not None:
    if not isinstance(sig, dict):
        signature_ok = False
        issues.append("signature must be object")
    else:
        st = str(sig.get("type", "")).strip()
        sig_type = st
        sv = str(sig.get("value", "")).strip()
        if st in ("sha256", "gpg", "cosign") and not sv:
            signature_ok = False
            issues.append("signature.value required for configured signature.type")
        if st and st not in ("none", "sha256", "gpg", "cosign"):
            signature_ok = False
            issues.append(f"unsupported signature.type '{st}'")
        target = str(sig.get("target", "plugin.json") or "plugin.json").strip()
        target_path = os.path.join(dest, target)
        if st == "sha256" and exists:
            if not os.path.isfile(target_path):
                signature_ok = False
                issues.append(f"sha256 target not found: {target}")
            else:
                try:
                    import hashlib
                    h = hashlib.sha256()
                    with open(target_path, "rb") as f:
                        for chunk in iter(lambda: f.read(65536), b""):
                            h.update(chunk)
                    actual = h.hexdigest()
                    sig_digest = actual.lower()
                    if actual.lower() != sv.lower():
                        signature_ok = False
                        issues.append(f"sha256 mismatch for {target}: expected={sv} actual={actual}")
                except Exception as e:
                    signature_ok = False
                    issues.append(f"sha256 verification failed for {target}: {e}")
        elif st == "gpg" and exists:
            sig_file = str(sig.get("file", f"{target}.asc") or f"{target}.asc").strip()
            sig_path = os.path.join(dest, sig_file)
            if not os.path.isfile(target_path):
                signature_ok = False
                issues.append(f"gpg target not found: {target}")
            elif not os.path.isfile(sig_path):
                signature_ok = False
                issues.append(f"gpg signature file not found: {sig_file}")
            else:
                import shutil, subprocess
                if shutil.which("gpg") is None:
                    signature_ok = False
                    issues.append("gpg command not found for signature verification")
                else:
                    try:
                        proc = subprocess.run(
                            ["gpg", "--status-fd", "1", "--verify", sig_path, target_path],
                            stdout=subprocess.PIPE,
                            stderr=subprocess.DEVNULL,
                            universal_newlines=True,
                        )
                        if proc.returncode != 0:
                            signature_ok = False
                            issues.append(f"gpg verification failed for {target}")
                        else:
                            for line in (proc.stdout or "").splitlines():
                                if "VALIDSIG " in line:
                                    parts = line.split()
                                    if "VALIDSIG" in parts:
                                        i = parts.index("VALIDSIG")
                                        if i + 1 < len(parts):
                                            signer_fingerprint = parts[i + 1].strip().lower()
                                            break
                    except Exception as e:
                        signature_ok = False
                        issues.append(f"gpg verification error for {target}: {e}")
        elif st == "cosign" and exists:
            sig_file = str(sig.get("file", f"{target}.sig") or f"{target}.sig").strip()
            sig_path = os.path.join(dest, sig_file)
            key_file = str(sig.get("key", "") or "").strip()
            key_path = os.path.join(dest, key_file) if key_file else ""
            if not os.path.isfile(target_path):
                signature_ok = False
                issues.append(f"cosign target not found: {target}")
            elif not os.path.isfile(sig_path):
                signature_ok = False
                issues.append(f"cosign signature file not found: {sig_file}")
            elif not key_path or not os.path.isfile(key_path):
                signature_ok = False
                issues.append("cosign key file missing (set signature.key)")
            else:
                try:
                    h = hashlib.sha256()
                    with open(key_path, "rb") as f:
                        for chunk in iter(lambda: f.read(65536), b""):
                            h.update(chunk)
                    cosign_key_sha256 = h.hexdigest().lower()
                except Exception as e:
                    signature_ok = False
                    issues.append(f"cosign key hash failed: {e}")
                if shutil.which("cosign") is None:
                    signature_ok = False
                    issues.append("cosign command not found for signature verification")
                else:
                    try:
                        proc = subprocess.run(
                            ["cosign", "verify-blob", "--signature", sig_path, "--key", key_path, target_path],
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                        )
                        if proc.returncode != 0:
                            signature_ok = False
                            issues.append(f"cosign verification failed for {target}")
                    except Exception as e:
                        signature_ok = False
                        issues.append(f"cosign verification error for {target}: {e}")

def as_set(v):
    if isinstance(v, list):
        return {str(x).strip().lower() for x in v if str(x).strip()}
    return set()

if signature_ok and sig_type in ("sha256", "gpg", "cosign"):
    sec = policy.get(sig_type, {})
    if sec is None:
        sec = {}
    if not isinstance(sec, dict):
        issues.append(f"trust_policy: section '{sig_type}' must be object")
        signature_ok = False
        sec = {}
    policy_applied = bool(sec)
    if sig_type == "sha256":
        trusted = as_set(sec.get("trusted_digests"))
        revoked = as_set(sec.get("revoked_digests"))
        if sig_digest and sig_digest in revoked:
            signature_ok = False
            issues.append(f"signature digest revoked by trust policy: {sig_digest}")
        if trusted and sig_digest not in trusted:
            signature_ok = False
            issues.append("signature digest not present in trust policy trusted_digests")
    elif sig_type == "gpg":
        trusted = as_set(sec.get("trusted_fingerprints"))
        revoked = as_set(sec.get("revoked_fingerprints"))
        if signer_fingerprint and signer_fingerprint in revoked:
            signature_ok = False
            issues.append(f"signature signer fingerprint revoked by trust policy: {signer_fingerprint}")
        if trusted and signer_fingerprint not in trusted:
            signature_ok = False
            issues.append("signature signer fingerprint not present in trust policy trusted_fingerprints")
    elif sig_type == "cosign":
        trusted = as_set(sec.get("trusted_key_sha256"))
        revoked = as_set(sec.get("revoked_key_sha256"))
        if cosign_key_sha256 and cosign_key_sha256 in revoked:
            signature_ok = False
            issues.append(f"cosign key hash revoked by trust policy: {cosign_key_sha256}")
        if trusted and cosign_key_sha256 not in trusted:
            signature_ok = False
            issues.append("cosign key hash not present in trust policy trusted_key_sha256")

ok = exists and manifest_ok and registry_has and compat_ok and signature_ok and len(issues) == 0
out = {
    "plugin_contract_version": 1,
    "name": name,
    "root": root,
    "exists": exists,
    "manifest_ok": manifest_ok,
    "registry_has": registry_has,
    "compat_ok": compat_ok,
    "signature_ok": signature_ok,
    "signature_type": sig_type,
    "signature_digest": sig_digest,
    "signer_fingerprint": signer_fingerprint,
    "cosign_key_sha256": cosign_key_sha256,
    "trust_policy_file": policy_path,
    "require_trust_policy": require_policy,
    "trust_policy_applied": policy_applied,
    "trust": trust,
    "issues": issues,
    "ok": ok,
    "manifest": meta,
}
if json_mode:
    print(json.dumps(out, indent=2, sort_keys=True))
else:
    print(f"plugin={name} exists={exists} manifest_ok={manifest_ok} registry_has={registry_has} compat_ok={compat_ok} signature_ok={signature_ok} trust={trust or '-'} ok={ok}")
    for i in issues:
        print(f"- {i}")
raise SystemExit(0 if ok else 2)
PY
        ;;

      remove)
        name="${1:-}"
        shift || true
        [[ -n "$name" ]] || { echo "ERROR: plugin remove requires <name>" >&2; exit 2; }
        plugin_validate_name_or_die "$name" "plugin remove"
        if [[ "$MODE" == "installed" ]]; then
          need_root_for plugin
        fi
        plug_root="$(plugin_root_dir)"
        reg_file="$(plugin_registry_file)"
        audit_log_append "plugin-remove" "start" "name=$name root=$plug_root"
        python3 - "$name" "$plug_root" "$reg_file" <<'PY'
import json, os, shutil, sys, tempfile
name, root, reg_file = sys.argv[1:4]
dest = os.path.join(root, name)
registry = {"plugins": []}
if os.path.exists(reg_file):
    try:
        with open(reg_file, "r", encoding="utf-8") as f:
            registry = json.load(f)
    except Exception as e:
        print(f"ERROR: invalid plugin registry: {reg_file}: {e}", file=sys.stderr)
        raise SystemExit(2)
    if not isinstance(registry, dict):
        print(f"ERROR: invalid plugin registry shape: {reg_file}", file=sys.stderr)
        raise SystemExit(2)
plugins = registry.get("plugins") or []
if not isinstance(plugins, list):
    print(f"ERROR: invalid plugin registry plugins list: {reg_file}", file=sys.stderr)
    raise SystemExit(2)
plugins = [p for p in plugins if str(p.get("name","")) != name]
registry["plugins"] = plugins
os.makedirs(os.path.dirname(reg_file) or ".", exist_ok=True)

backup_dir = ""
registry_tmp = ""
removed = False
try:
    if os.path.isdir(dest):
        backup_dir = tempfile.mkdtemp(prefix=".plugin_remove_", dir=root)
        os.rmdir(backup_dir)
        os.replace(dest, backup_dir)
        removed = True
    fd, registry_tmp = tempfile.mkstemp(prefix=".plugin_registry.", dir=os.path.dirname(reg_file) or ".")
    os.close(fd)
    with open(registry_tmp, "w", encoding="utf-8") as f:
        json.dump(registry, f, indent=2, sort_keys=True)
        f.write("\n")
    os.replace(registry_tmp, reg_file)
    registry_tmp = ""
except Exception:
    if registry_tmp and os.path.exists(registry_tmp):
        os.unlink(registry_tmp)
    if backup_dir and os.path.exists(backup_dir):
        os.replace(backup_dir, dest)
    raise
finally:
    if removed and backup_dir and os.path.exists(backup_dir):
        shutil.rmtree(backup_dir)
print(f"removed plugin {name}")
PY
        audit_log_append "plugin-remove" "success" "name=$name root=$plug_root"
        ;;

      ""|-h|--help)
        command_usage plugin
        ;;
      *)
        echo "Unknown plugin subcommand: $sub" >&2
        command_usage plugin >&2
        exit 2
        ;;
    esac
}

linux_maint_cmd_serve() {
    S_HOST="127.0.0.1"
    S_PORT="9910"
    S_CMD_TIMEOUT="${LM_SERVE_CMD_TIMEOUT:-15}"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --host) S_HOST="$2"; shift 2;;
        --port) S_PORT="$2"; shift 2;;
        -h|--help) command_usage serve; exit 0;;
        *) echo "Unknown serve flag: $1" >&2; exit 2;;
      esac
    done
    if [[ ! "$S_PORT" =~ ^[0-9]+$ ]]; then
      echo "ERROR: --port must be numeric" >&2
      exit 2
    fi
    if [[ ! "$S_CMD_TIMEOUT" =~ ^[0-9]+$ ]] || (( S_CMD_TIMEOUT <= 0 )); then
      echo "ERROR: LM_SERVE_CMD_TIMEOUT must be a positive integer" >&2
      exit 2
    fi
    exec env S_CLI="${LM_SERVE_CLI:-$0}" S_CMD_TIMEOUT="$S_CMD_TIMEOUT" python3 - "$S_HOST" "$S_PORT" <<'PY'
import json, os, subprocess, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
try:
    from http.server import ThreadingHTTPServer
except ImportError:
    from socketserver import ThreadingMixIn
    class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
        pass
host, port = sys.argv[1], int(sys.argv[2])
cli = os.environ.get("S_CLI", "linux-maint")
cmd_timeout = int(os.environ.get("S_CMD_TIMEOUT", "15"))

def validate_payload(endpoint, payload):
    if not isinstance(payload, dict):
        return "response must be JSON object"
    if endpoint == "status":
        if "last_status" not in payload or "totals" not in payload:
            return "status payload missing contract fields"
        if not isinstance(payload.get("last_status"), dict) or not isinstance(payload.get("totals"), dict):
            return "status payload has invalid field types"
    elif endpoint == "report":
        if "status" not in payload or "trend" not in payload or "runtimes" not in payload:
            return "report payload missing contract fields"
        if not isinstance(payload.get("status"), dict) or not isinstance(payload.get("trend"), dict) or not isinstance(payload.get("runtimes"), dict):
            return "report payload has invalid field types"
    elif endpoint == "metrics":
        if "status" not in payload or "severity_totals" not in payload:
            return "metrics payload missing contract fields"
        if not isinstance(payload.get("status"), dict) or not isinstance(payload.get("severity_totals"), dict):
            return "metrics payload has invalid field types"
    elif endpoint == "history":
        if "runs" not in payload:
            return "history payload missing contract fields"
        if not isinstance(payload.get("runs"), list):
            return "history payload has invalid field types"
    return ""

def run_json(args):
    endpoint = args[0] if args else "unknown"
    try:
        proc = subprocess.run(
            [cli] + args,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            universal_newlines=True,
            timeout=cmd_timeout,
        )
    except subprocess.TimeoutExpired:
        return 504, json.dumps({
            "error": "command_timeout",
            "command": " ".join(args),
            "timeout_seconds": cmd_timeout,
        })
    except Exception as e:
        return 500, json.dumps({"error": str(e)})
    if proc.returncode != 0:
        return 500, json.dumps({
            "error": "command_failed",
            "command": " ".join(args),
            "rc": proc.returncode,
        })
    try:
        payload = json.loads(proc.stdout)
    except Exception:
        return 500, json.dumps({
            "error": "invalid_json",
            "command": " ".join(args),
        })
    validation_error = validate_payload(endpoint, payload)
    if validation_error:
        return 500, json.dumps({
            "error": "invalid_contract",
            "command": " ".join(args),
            "detail": validation_error,
        })
    return 200, json.dumps(payload, indent=2, sort_keys=True)

class H(BaseHTTPRequestHandler):
    def _send(self, code, body, ctype="application/json"):
        data = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)
    def log_message(self, format, *args):
        return
    def do_GET(self):
        p = self.path.split("?", 1)[0]
        if p == "/health":
            self._send(200, json.dumps({"ok": True, "service": "linux-maint serve"}))
            return
        if p == "/status":
            code, out = run_json(["status", "--json"])
            self._send(code, out)
            return
        if p == "/report":
            code, out = run_json(["report", "--json"])
            self._send(code, out)
            return
        if p == "/metrics":
            code, out = run_json(["metrics", "--json"])
            self._send(code, out)
            return
        if p == "/history":
            code, out = run_json(["history", "--json", "--last", "20"])
            self._send(code, out)
            return
        if p == "/":
            self._send(200, json.dumps({"routes": ["/health","/status","/report","/metrics","/history"]}))
            return
        self._send(404, json.dumps({"error":"not_found","path":p}))

class S(ThreadingHTTPServer):
    daemon_threads = True
    allow_reuse_address = True

S((host, port), H).serve_forever()
PY
}

linux_maint_cmd_agent() {
    A_ONCE=0
    A_INTERVAL=300
    A_MAX_RUNS=0
    A_DRY_RUN=0
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --once) A_ONCE=1; shift 1;;
        --interval) A_INTERVAL="$2"; shift 2;;
        --max-runs) A_MAX_RUNS="$2"; shift 2;;
        --dry-run) A_DRY_RUN=1; shift 1;;
        -h|--help) command_usage agent; exit 0;;
        *) echo "Unknown agent flag: $1" >&2; exit 2;;
      esac
    done
    if [[ "$MODE" == "installed" && "$A_DRY_RUN" -ne 1 ]]; then
      need_root_for agent
    fi
    [[ "$A_INTERVAL" =~ ^[0-9]+$ ]] || { echo "ERROR: --interval must be integer" >&2; exit 2; }
    (( A_INTERVAL > 0 )) || { echo "ERROR: --interval must be a positive integer" >&2; exit 2; }
    [[ "$A_MAX_RUNS" =~ ^[0-9]+$ ]] || { echo "ERROR: --max-runs must be integer" >&2; exit 2; }
    runs=0
    agent_rc=0
    while true; do
      runs=$((runs+1))
      run_rc=0
      if [[ "$A_DRY_RUN" -eq 1 ]]; then
        echo "agent dry-run iteration=$runs"
      else
        set +e
        "$0" run
        run_rc=$?
        set -e
        if [[ "$run_rc" -ne 0 ]]; then
          agent_rc="$run_rc"
        fi
      fi
      if [[ "$A_ONCE" -eq 1 ]]; then
        break
      fi
      if [[ "$A_MAX_RUNS" -gt 0 && "$runs" -ge "$A_MAX_RUNS" ]]; then
        break
      fi
      sleep "$A_INTERVAL"
    done
    exit "$agent_rc"
}

linux_maint_cmd_policy() {
    psub="${1:-}"
    shift || true
    case "$psub" in
      init)
        out="${1:-policy.conf}"
        cat > "$out" <<'EOF'
# linux-maint gate policy
max_crit=0
max_warn=10
max_unknown=5
max_skip=100
require_overall=
EOF
        echo "created policy template: $out"
        ;;
      lint)
        pfile="${1:-}"
        [[ -n "$pfile" && -f "$pfile" ]] || { echo "ERROR: policy file required" >&2; exit 2; }
        python3 - "$pfile" <<'PY'
import sys
p=sys.argv[1]
allowed={"max_crit","max_warn","max_unknown","max_skip","require_overall"}
allowed_overall={"","OK","WARN","CRIT","UNKNOWN","SKIP"}
bad=[]
seen=set()
for ln,raw in enumerate(open(p,encoding="utf-8",errors="ignore"),start=1):
    line=raw.strip()
    if not line or line.startswith("#"):
        continue
    if "=" not in line:
        bad.append((ln,"missing '='"))
        continue
    k,v=line.split("=",1); k=k.strip(); v=v.strip()
    if k not in allowed:
        bad.append((ln,f"unknown key {k}"))
        continue
    if k in seen:
        bad.append((ln,f"duplicate key {k}"))
        continue
    seen.add(k)
    if k!="require_overall" and not v.isdigit():
        bad.append((ln,f"{k} must be integer"))
    if k=="require_overall" and v.upper() not in allowed_overall:
        bad.append((ln, f"require_overall must be one of {','.join(sorted(x for x in allowed_overall if x))} or empty"))
if bad:
    for ln,msg in bad:
        print(f"{p}:{ln}: {msg}")
    raise SystemExit(2)
print("policy lint ok")
PY
        ;;
      eval)
        if [[ "${1:-}" != "--policy" || -z "${2:-}" ]]; then
          echo "Usage: linux-maint policy e""val --policy <file> [--json]" >&2
          exit 2
        fi
        pfile="$2"; shift 2
        exec "$0" gate --policy "$pfile" "$@"
        ;;
      ""|-h|--help)
        command_usage policy
        ;;
      *)
        echo "Unknown policy subcommand: $psub" >&2
        exit 2
        ;;
    esac
}

linux_maint_cmd_federate() {
    FED_INPUT=""
    FED_JSON=0
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --input) FED_INPUT="$2"; shift 2;;
        --json) FED_JSON=1; shift 1;;
        -h|--help) command_usage federate; exit 0;;
        *) echo "Unknown federate flag: $1" >&2; exit 2;;
      esac
    done
    [[ -n "$FED_INPUT" ]] || { echo "ERROR: --input file1,file2 is required" >&2; exit 2; }
    FED_INPUT="$FED_INPUT" FED_JSON="$FED_JSON" python3 - <<'PY'
import json, os, sys
paths=[p.strip() for p in os.environ.get("FED_INPUT","").split(",") if p.strip()]
json_mode=os.environ.get("FED_JSON","0")=="1"
tot={"CRIT":0,"WARN":0,"UNKNOWN":0,"SKIP":0,"OK":0}
clusters=[]
errors=[]
for p in paths:
    try:
        with open(p, encoding="utf-8") as fh:
            o=json.load(fh)
    except Exception as e:
        errors.append(f"{p}: {e}")
        continue
    if not isinstance(o, dict):
        errors.append(f"{p}: top-level JSON must be object")
        continue
    last_status = o.get("last_status")
    totals = o.get("totals")
    if not isinstance(last_status, dict) or not isinstance(totals, dict):
        errors.append(f"{p}: missing status/totals contract fields")
        continue
    overall = str(last_status.get("overall", "UNKNOWN") or "UNKNOWN")
    t=o.get("totals") or {}
    for k in tot:
        try:
            tot[k]+=int(t.get(k,0))
        except Exception:
            errors.append(f"{p}: totals.{k} must be integer")
            break
    else:
        cluster_totals={}
        for k in tot:
            try:
                cluster_totals[k]=int(t.get(k,0) or 0)
            except Exception:
                cluster_totals[k]=0
        clusters.append({"file":p,"overall":overall,"totals":cluster_totals})
        continue
    cluster_totals={}
if errors:
    for err in errors:
        print(f"ERROR: invalid federate input: {err}", file=sys.stderr)
    raise SystemExit(2)
out={"federation_contract_version":1,"clusters":clusters,"totals":tot}
if json_mode:
    print(json.dumps(out,indent=2,sort_keys=True))
else:
    print("=== linux-maint federate ===")
    for c in clusters:
        print(f"{c['file']} overall={c['overall']} CRIT={c['totals']['CRIT']} WARN={c['totals']['WARN']} UNKNOWN={c['totals']['UNKNOWN']} SKIP={c['totals']['SKIP']} OK={c['totals']['OK']}")
    print(f"TOTAL CRIT={tot['CRIT']} WARN={tot['WARN']} UNKNOWN={tot['UNKNOWN']} SKIP={tot['SKIP']} OK={tot['OK']}")
PY
}

linux_maint_cmd_ai_assist() {
    AA_JSON=0
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --json) AA_JSON=1; shift 1;;
        -h|--help) command_usage ai-assist; exit 0;;
        *) echo "Unknown ai-assist flag: $1" >&2; exit 2;;
      esac
    done
    set +e
    st_json="$(NO_COLOR=1 "$0" status --json --reasons 8 --problems 12 2>/dev/null)"
    st_rc=$?
    set -e
    ST_JSON="$st_json" ST_RC="$st_rc" AA_JSON="$AA_JSON" python3 - <<'PY'
import json, os, sys
source_rc = int(os.environ.get("ST_RC", "0"))
if source_rc != 0:
    print("ERROR: ai-assist requires a successful status --json snapshot", file=sys.stderr)
    raise SystemExit(2)
raw = os.environ.get("ST_JSON","")
try:
    obj=json.loads(raw)
except Exception:
    print("ERROR: ai-assist requires valid JSON from status --json", file=sys.stderr)
    raise SystemExit(2)
if not isinstance(obj, dict) or "last_status" not in obj:
    print("ERROR: ai-assist requires status --json contract fields", file=sys.stderr)
    raise SystemExit(2)
overall=str((obj.get("last_status") or {}).get("overall","UNKNOWN"))
reasons=[r.get("reason") for r in (obj.get("reason_rollup") or []) if isinstance(r,dict)]
hints=[]
map_hint={
  "ssh_unreachable":"Check network path, DNS, and SSH keys.",
  "missing_dependency":"Install missing command on runner/host.",
  "service_inactive":"Start/enable required service.",
  "config_missing":"Run linux-maint init and populate config files.",
  "runtime_exceeded":"Increase monitor timeout or investigate slow hosts.",
}
for r in reasons[:5]:
    if r in map_hint and map_hint[r] not in hints:
        hints.append(map_hint[r])
if not hints:
    hints.append("Run linux-maint doctor and inspect top reasons.")
risk_note="heuristic"
confidence_level="low"
if len(reasons) >= 5:
    confidence_level="high"
elif len(reasons) >= 2:
    confidence_level="medium"
out={"ai_assist_contract_version":1,"overall":overall,"top_reasons":reasons[:5],"hints":hints,"confidence":{"level":confidence_level,"basis":"reason_rollup_size","value":len(reasons)},"risk_note":risk_note}
if os.environ.get("AA_JSON","0")=="1":
    print(json.dumps(out,indent=2,sort_keys=True))
else:
    print("=== linux-maint ai-assist ===")
    print(f"overall={overall}")
    print(f"confidence={confidence_level} basis=reason_rollup_size value={len(reasons)}")
    print("hints:")
    for h in hints:
      print(f"- {h}")
PY
}

linux_maint_cmd_predict() {
    P_LAST=30
    P_JSON=0
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --last) P_LAST="$2"; shift 2;;
        --json) P_JSON=1; shift 1;;
        -h|--help) command_usage predict; exit 0;;
        *) echo "Unknown predict flag: $1" >&2; exit 2;;
      esac
    done
    [[ "$P_LAST" =~ ^[0-9]+$ ]] || { echo "ERROR: --last must be integer" >&2; exit 2; }
    (( P_LAST > 0 )) || { echo "ERROR: --last must be a positive integer" >&2; exit 2; }
    if [[ "$MODE" == "repo" ]]; then
      predict_state_dir="${LM_STATE_DIR:-$REPO_LOG_DIR}"
    else
      predict_state_dir="${LM_STATE_DIR:-/var/lib/linux_maint}"
    fi
    predict_history_db="${LM_HISTORY_DB:-$predict_state_dir/run_index.sqlite}"
    predict_history_index="${LM_RUN_INDEX_FILE:-$predict_state_dir/run_index.jsonl}"
    predict_has_history=0
    if [[ -f "$predict_history_db" || -f "$predict_history_index" ]]; then
      predict_has_history=1
    elif [[ -z "${LM_HISTORY_DB:-}" && -z "${LM_RUN_INDEX_FILE:-}" ]]; then
      for alt in /var/tmp/run_index.jsonl /var/tmp/linux_maint/run_index.jsonl /tmp/linux_maint/run_index.jsonl; do
        if [[ -f "$alt" ]]; then
          predict_has_history=1
          break
        fi
      done
    fi
    if [[ "$predict_has_history" -eq 0 ]]; then
      hist_json='{"history_json_contract_version":1,"runs":[]}'
      hist_rc=0
    else
      set +e
      hist_json="$(NO_COLOR=1 "$0" history --json --last "$P_LAST" 2>/dev/null)"
      hist_rc=$?
      set -e
    fi
    HIST_JSON="$hist_json" HIST_RC="$hist_rc" P_JSON="$P_JSON" python3 - <<'PY'
import json, os, sys
source_rc = int(os.environ.get("HIST_RC", "0"))
if source_rc != 0:
    print("ERROR: predict requires a successful history --json snapshot", file=sys.stderr)
    raise SystemExit(2)
raw = os.environ.get("HIST_JSON","")
try:
    obj=json.loads(raw)
except Exception:
    print("ERROR: predict requires valid JSON from history --json", file=sys.stderr)
    raise SystemExit(2)
if not isinstance(obj, dict) or "runs" not in obj:
    print("ERROR: predict requires history --json contract fields", file=sys.stderr)
    raise SystemExit(2)
runs=obj.get("runs") or []
if not isinstance(runs, list):
    print("ERROR: predict requires runs list from history --json", file=sys.stderr)
    raise SystemExit(2)
for idx, run in enumerate(runs):
    if not isinstance(run, dict):
        print(f"ERROR: predict requires run objects from history --json (runs[{idx}])", file=sys.stderr)
        raise SystemExit(2)
    hosts = run.get("hosts")
    if hosts is None:
        hosts = {}
    if not isinstance(hosts, dict):
        print(f"ERROR: predict requires hosts objects from history --json (runs[{idx}].hosts)", file=sys.stderr)
        raise SystemExit(2)
    for key in ("crit", "warn", "unknown"):
        try:
            int(hosts.get(key, 0) or 0)
        except Exception:
            print(f"ERROR: predict requires integer host totals from history --json (runs[{idx}].hosts.{key})", file=sys.stderr)
            raise SystemExit(2)
crit=sum(int(((r.get("hosts") or {}).get("crit",0) or 0)) for r in runs if isinstance(r,dict))
warn=sum(int(((r.get("hosts") or {}).get("warn",0) or 0)) for r in runs if isinstance(r,dict))
unk=sum(int(((r.get("hosts") or {}).get("unknown",0) or 0)) for r in runs if isinstance(r,dict))
n=max(len(runs),1)
score=round((crit*3 + warn*1 + unk*2)/n,2)
risk="low"
if score>=10: risk="high"
elif score>=4: risk="medium"
confidence="low"
if len(runs) >= 20:
    confidence="high"
elif len(runs) >= 8:
    confidence="medium"
recommended_action="observe"
if risk == "high":
    recommended_action="open_incident"
elif risk == "medium":
    recommended_action="schedule_investigation"
out={"predict_contract_version":1,"runs_considered":len(runs),"risk_score":score,"risk_level":risk,"confidence_level":confidence,"recommended_action":recommended_action,"totals":{"crit":crit,"warn":warn,"unknown":unk}}
if os.environ.get("P_JSON","0")=="1":
    print(json.dumps(out,indent=2,sort_keys=True))
else:
    print("=== linux-maint predict ===")
    print(f"runs={len(runs)} risk_score={score} risk_level={risk} confidence_level={confidence} action={recommended_action} CRIT={crit} WARN={warn} UNKNOWN={unk}")
PY
}
