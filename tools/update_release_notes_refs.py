#!/usr/bin/env python3
import re
import sys
from pathlib import Path


def repo_relative(root: Path, path: Path) -> str:
    return path.resolve().relative_to(root.resolve()).as_posix()


def normalize_notes_ref(root: Path, readme_path: Path, notes_path: Path) -> str:
    try:
        notes_rel = repo_relative(root, notes_path)
    except ValueError:
        notes_rel = notes_path.as_posix()
    try:
        readme_prefix = str(readme_path.parent.relative_to(root)) + "/"
    except ValueError:
        readme_prefix = readme_path.parent.as_posix().rstrip("/") + "/"
    if notes_rel.startswith(readme_prefix):
        notes_rel = notes_rel[len(readme_prefix):]
    if not notes_rel.startswith("docs/"):
        match = re.search(r"(docs/release_notes/release_notes_v[0-9]+\.[0-9]+\.[0-9]+\.md)$", notes_rel)
        if match:
            notes_rel = match.group(1)
        else:
            notes_rel = f"docs/{Path(notes_rel).parent.name}/{Path(notes_rel).name}"
    return notes_rel


def version_from_notes(notes_ref: str) -> str:
    match = re.search(r"release_notes_v([0-9]+\.[0-9]+\.[0-9]+)\.md$", notes_ref)
    if not match:
        raise ValueError(f"cannot infer version from notes path: {notes_ref}")
    return match.group(1)


def update_docs_hub(path: Path, notes_ref: str) -> None:
    lines = path.read_text(encoding="utf-8").splitlines()
    out = []
    pat = re.compile(r"`(docs/release_notes/release_notes_v[^`]+)`")
    replaced = False
    for line in lines:
        if line.strip().startswith("- Release notes (latest):"):
            found = pat.findall(line)
            items = [notes_ref] + [ref for ref in found if ref != notes_ref]
            items = items[:2]
            line = "- Release notes (latest): " + ", ".join(f"`{ref}`" for ref in items)
            replaced = True
        out.append(line)
    if replaced:
        path.write_text("\n".join(out) + "\n", encoding="utf-8")


def update_release_notes_index(path: Path, notes_ref: str) -> None:
    version = version_from_notes(notes_ref)
    notes_name = Path(notes_ref).name
    lines = path.read_text(encoding="utf-8").splitlines()
    table_row = f"| `v{version}` | see release notes | [{notes_name}]({notes_name}) |"
    history_item = f"- [{notes_name}]({notes_name})"

    out = []
    in_latest = False
    inserted_latest = False
    in_history = False
    inserted_history = False
    saw_latest_header = False
    saw_history_header = False

    for line in lines:
        stripped = line.strip()

        if stripped == "## Latest releases":
            saw_latest_header = True
            in_latest = False
            out.append(line)
            continue
        if saw_latest_header and stripped.startswith("| Version |"):
            in_latest = True
            out.append(line)
            continue
        if in_latest and stripped.startswith("| ---"):
            out.append(line)
            if not inserted_latest:
                out.append(table_row)
                inserted_latest = True
            continue
        if in_latest and stripped.startswith("| `v"):
            if notes_name in line or f"`v{version}`" in line:
                continue
            out.append(line)
            continue
        if in_latest and stripped.startswith("## "):
            in_latest = False

        if stripped == "## Full history":
            saw_history_header = True
            in_history = True
            out.append(line)
            continue
        if in_history and stripped.startswith("- [release_notes_v"):
            if notes_name in line:
                continue
            if not inserted_history:
                out.append(history_item)
                inserted_history = True
            out.append(line)
            continue
        if in_history and stripped.startswith("## "):
            in_history = False

        out.append(line)

    if saw_latest_header and not inserted_latest:
        raise SystemExit(f"failed to update latest releases table in {path}")
    if saw_history_header and not inserted_history:
        out.append("")
        out.append("## Full history")
        out.append(history_item)

    path.write_text("\n".join(out) + "\n", encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: update_release_notes_refs.py <docs-readme> <notes-path>", file=sys.stderr)
        return 2
    readme_path = Path(sys.argv[1]).resolve()
    notes_path = Path(sys.argv[2]).resolve()
    root = Path(__file__).resolve().parent.parent
    notes_ref = normalize_notes_ref(root, readme_path, notes_path)
    update_docs_hub(readme_path, notes_ref)
    release_index = readme_path.parent / "release_notes/README.md"
    if release_index.exists():
        update_release_notes_index(release_index, notes_ref)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
