#!/usr/bin/env python3
"""Minimal JSON Schema validator (subset) for repo tests.

Supported keywords:
- type (string or list)
- required (list of keys)
- properties (object)
- items (schema)
- enum (list)
- additionalProperties (bool)
"""

import json
import sys
from typing import Any, Dict, Iterable, List, Tuple


def _fail(path: str, msg: str) -> None:
    raise ValueError(f"{path}: {msg}")


def _type_matches(expected: Any, value: Any) -> bool:
    if expected is None:
        return value is None
    if expected == "null":
        return value is None
    if expected == "string":
        return isinstance(value, str)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    return False


def _ensure_type(schema_type: Any, value: Any, path: str) -> None:
    if schema_type is None:
        return
    if isinstance(schema_type, list):
        if not any(_type_matches(t, value) for t in schema_type):
            _fail(path, f"type mismatch (expected one of {schema_type}, got {type(value).__name__})")
    else:
        if not _type_matches(schema_type, value):
            _fail(path, f"type mismatch (expected {schema_type}, got {type(value).__name__})")


def validate(schema: Dict[str, Any], value: Any, path: str = "$") -> None:
    if "type" in schema:
        _ensure_type(schema.get("type"), value, path)

    if "enum" in schema:
        if value not in schema["enum"]:
            _fail(path, f"value {value!r} not in enum")

    schema_type = schema.get("type")
    if schema_type == "object" or (isinstance(schema_type, list) and "object" in schema_type):
        props = schema.get("properties", {})
        required = schema.get("required", [])
        for key in required:
            if not isinstance(value, dict) or key not in value:
                _fail(path, f"missing required key {key!r}")
        if isinstance(value, dict):
            for k, v in value.items():
                if k in props:
                    validate(props[k], v, f"{path}.{k}")
                elif schema.get("additionalProperties") is False:
                    _fail(path, f"unexpected key {k!r}")

    if schema_type == "array" or (isinstance(schema_type, list) and "array" in schema_type):
        if isinstance(value, list) and "items" in schema:
            for i, item in enumerate(value):
                validate(schema["items"], item, f"{path}[{i}]")


def main(argv: List[str]) -> int:
    if len(argv) != 2:
        print(f"Usage: {argv[0]} <schema.json>", file=sys.stderr)
        return 2
    schema_path = argv[1]
    schema = json.load(open(schema_path, "r", encoding="utf-8"))
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"ERROR: invalid JSON input: {e}", file=sys.stderr)
        return 2
    try:
        validate(schema, payload)
    except ValueError as e:
        print(f"SCHEMA FAIL: {e}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
