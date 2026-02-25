#!/usr/bin/env python3
import sys, json, os
from pathlib import Path

def parse_line(line: str):
    parts=line.strip().split()
    d={}
    for p in parts:
        if '=' in p:
            k,v=p.split('=',1)
            d[k]=v
    return d

def sev(st):
    return {'OK':0,'SKIP':0,'WARN':1,'CRIT':2,'UNKNOWN':3}.get(st,3)

def key(row):
    return (row.get('monitor',''), row.get('host',''))

def canonicalize_rows_worst(rows):
    """Deduplicate rows by (monitor,host) keeping the worst status.

    Tie-break rule when severity is equal: keep the later row (last-wins).
    """
    out={}
    for r in rows:
        k=key(r)
        if k not in out:
            out[k]=r
            continue
        prev=out[k]
        prev_sev=sev(prev.get('status','UNKNOWN'))
        cur_sev=sev(r.get('status','UNKNOWN'))
        if cur_sev > prev_sev:
            out[k]=r
        elif cur_sev == prev_sev:
            out[k]=r
    return out

def load_summary_map(path: Path):
    rows=[]
    if not path.exists():
        return {}
    for line in path.read_text(errors='ignore').splitlines():
        if line.startswith('monitor='):
            rows.append(parse_line(line))
    return canonicalize_rows_worst(rows)

def main(prev_path, cur_path, fmt='text'):
    prev_map=load_summary_map(Path(prev_path))
    cur_map=load_summary_map(Path(cur_path))

    color = os.environ.get("LM_COLOR", "0") == "1"

    def c(s, code):
        if not color:
            return s
        return f"\033[{code}m{s}\033[0m"

    def color_status(st, text=None):
        label = text if text is not None else st
        if st == "CRIT":
            return c(label, "1;31")
        if st == "WARN":
            return c(label, "1;33")
        if st == "OK":
            return c(label, "1;32")
        if st == "UNKNOWN":
            return c(label, "1;35")
        if st == "SKIP":
            return c(label, "1;36")
        return label

    new_fail=[]
    recovered=[]
    changed=[]
    still_bad=[]

    for k, r in cur_map.items():
        prev_r = prev_map.get(k)
        cur_st=r.get('status','UNKNOWN')
        prev_st=prev_r.get('status','MISSING') if prev_r else 'MISSING'

        if prev_r is None:
            # new entity
            if cur_st != 'OK':
                changed.append({'type':'new', 'key':k, 'prev':None, 'cur':r})
            continue

        if prev_st != cur_st:
            # transition
            if prev_st == 'OK' and cur_st in ('WARN','CRIT','UNKNOWN'):
                new_fail.append((k, prev_r, r))
            elif prev_st in ('WARN','CRIT','UNKNOWN') and cur_st == 'OK':
                recovered.append((k, prev_r, r))
            else:
                changed.append({'type':'transition', 'key':k, 'prev':prev_r, 'cur':r})
        else:
            if cur_st in ('WARN','CRIT','UNKNOWN'):
                still_bad.append((k, r))

    # sort: by severity desc then monitor/host
    new_fail.sort(key=lambda x: (-sev(x[2].get('status','UNKNOWN')), x[0]))
    recovered.sort(key=lambda x: (x[0]))
    still_bad.sort(key=lambda x: (-sev(x[1].get('status','UNKNOWN')), x[0]))

    if fmt=='json':
        out={
            'new_failures':[{'monitor':k[0],'host':k[1],'prev':prev,'cur':cur} for k, prev, cur in new_fail],
            'recovered':[{'monitor':k[0],'host':k[1],'prev':prev,'cur':cur} for k, prev, cur in recovered],
            'still_bad':[{'monitor':k[0],'host':k[1],'cur':cur} for k, cur in still_bad],
            'changed':changed,
        }
        print(json.dumps(out, indent=2, sort_keys=True))
        return 0

    def brief(row):
        st=row.get('status','?')
        reason=row.get('reason','')
        extra=''
        if reason:
            extra=f" reason={reason}"
        return f"{color_status(st)}{extra}"

    print(f"diff_prev={prev_path}")
    print(f"diff_cur={cur_path}")
    print("")

    new_label = f"NEW_FAILURES {len(new_fail)}"
    if len(new_fail) > 0:
        new_label = c(new_label, "1;31")
    print(new_label)
    for k, prev, cur in new_fail[:80]:
        print(f"- {k[1]} {k[0]}: {brief(prev)} -> {brief(cur)}")

    print("")
    rec_label = f"RECOVERED {len(recovered)}"
    if len(recovered) > 0:
        rec_label = c(rec_label, "1;32")
    print(rec_label)
    for k, prev, cur in recovered[:80]:
        print(f"- {k[1]} {k[0]}: {brief(prev)} -> {brief(cur)}")

    print("")
    still_label = f"STILL_BAD {len(still_bad)}"
    if len(still_bad) > 0:
        still_label = c(still_label, "1;33")
    print(still_label)
    for k, cur in still_bad[:120]:
        print(f"- {k[1]} {k[0]}: {brief(cur)}")

    return 0

if __name__=='__main__':
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <prev_summary> <cur_summary> [--json]", file=sys.stderr)
        sys.exit(2)
    prev=sys.argv[1]; cur=sys.argv[2]
    fmt='json' if (len(sys.argv)>3 and sys.argv[3]=='--json') else 'text'
    sys.exit(main(prev, cur, fmt))
