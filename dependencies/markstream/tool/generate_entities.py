#!/usr/bin/env python3
"""Convert a downloaded WHATWG entities.json snapshot; no network or packages.

Usage: python3 tool/generate_entities.py /path/to/entities.json 2026-10-17
"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

source_path, snapshot_date = sys.argv[1:]
source = Path(source_path).read_bytes()
entities = json.loads(source)
output = Path(__file__).resolve().parents[1] / "lib/src/core/html/named_entities.dart"
lines = [
    f"// Generated from WHATWG HTML named character references ({snapshot_date}).",
    "// https://html.spec.whatwg.org/entities.json",
    f"// Source SHA-256: {hashlib.sha256(source).hexdigest()}",
    "// Copyright WHATWG (Apple, Google, Mozilla, Microsoft).",
    "// BSD-3-Clause; see THIRD_PARTY_NOTICES.md.",
    "const namedEntities = <String, String>{",
]
for name, entity in sorted(entities.items()):
    if name.endswith(";"):
        key = json.dumps(name[1:-1], ensure_ascii=True).replace("$", "\\$")
        value = json.dumps(entity["characters"], ensure_ascii=True).replace("$", "\\$")
        lines.append(f"  {key}: {value},")
lines.append("};\n")
output.write_text("\n".join(lines), encoding="utf-8")
subprocess.run(["dart", "format", str(output)], check=True)
