#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from typing import Any, Dict, List, Set


def _load_json(path: str, *, label: str) -> Dict[str, List[str]]:
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except FileNotFoundError as e:
        raise RuntimeError(f"{label} missing {path}. Run `flutter gen-l10n` first.") from e
    except json.JSONDecodeError as e:
        raise RuntimeError(f"{label} {path} is not valid JSON: {e}") from e
    return _normalize(data)


def _normalize(data: Any) -> Dict[str, List[str]]:
    if not isinstance(data, dict):
        raise RuntimeError("desiredFileName.txt JSON root must be an object.")
    normalized: Dict[str, List[str]] = {}
    for locale, keys in data.items():
        if not isinstance(locale, str):
            raise RuntimeError("desiredFileName.txt locale keys must be strings.")
        if keys is None:
            normalized[locale] = []
            continue
        if not isinstance(keys, list) or not all(isinstance(k, str) for k in keys):
            raise RuntimeError(f"desiredFileName.txt value for {locale} must be a string array.")
        normalized[locale] = keys
    return normalized


def _diff_new_keys(base: Dict[str, List[str]], head: Dict[str, List[str]]) -> Dict[str, Set[str]]:
    out: Dict[str, Set[str]] = {}
    for locale, head_keys in head.items():
        base_keys = base.get(locale, [])
        new = set(head_keys) - set(base_keys)
        if new:
            out[locale] = new
    return out


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "Usage: check_no_new_untranslated.py <base_desiredFileName.txt> <head_desiredFileName.txt>",
            file=sys.stderr,
        )
        return 2

    base_path = sys.argv[1].strip()
    head_path = sys.argv[2].strip()
    if not base_path or not head_path:
        print("base/head paths must be non-empty.", file=sys.stderr)
        return 2

    base = _load_json(base_path, label="base")
    head = _load_json(head_path, label="head")
    new_by_locale = _diff_new_keys(base, head)

    if not new_by_locale:
        print("OK: no new untranslated messages in desiredFileName.txt.")
        return 0

    print(
        "FAIL: new untranslated messages detected (not allowed). "
        "Please fill translations in all 4 ARB files and re-run `flutter gen-l10n`:",
        file=sys.stderr,
    )
    for locale in sorted(new_by_locale.keys()):
        keys = sorted(new_by_locale[locale])
        print(f"- {locale}: +{len(keys)}", file=sys.stderr)
        for k in keys[:60]:
            print(f"  - {k}", file=sys.stderr)
        if len(keys) > 60:
            print(f"  ... and {len(keys) - 60} more", file=sys.stderr)
    return 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as e:
        print(f"FAIL: {e}", file=sys.stderr)
        raise SystemExit(1)
