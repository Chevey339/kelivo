#!/usr/bin/env python3
"""Extract the four GFM extension sections from a saved official spec HTML page.

Usage: python3 tool/extract_gfm_fixtures.py /path/to/gfm.html
"""
from html.parser import HTMLParser
from pathlib import Path
import json
import re
import sys

SECTIONS = {
    "Tables (extension)", "Task list items (extension)",
    "Strikethrough (extension)", "Autolinks (extension)",
}

class Examples(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.section = ""
        self.heading = None
        self.example = None
        self.depth = 0
        self.code = None
        self.parts = []
        self.tab = False
        self.examples = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "h2":
            self.heading = []
        if tag == "div":
            if self.example is not None:
                self.depth += 1
            elif attrs.get("class") == "example":
                self.example = {"example": int(attrs["id"].removeprefix("example-")), "section": self.section}
                self.depth = 1
        if self.example is not None and tag == "code":
            kind = attrs.get("class", "").removeprefix("language-")
            if kind in {"markdown", "html"}:
                self.code = kind
                self.parts = []
        if self.code is not None and tag == "span" and attrs.get("class") == "tab":
            self.tab = True

    def handle_endtag(self, tag):
        if tag == "h2" and self.heading is not None:
            self.section = re.sub(r"^\d+(?:\.\d+)*\s*", "", "".join(self.heading).strip()).strip()
            self.heading = None
        if tag == "span":
            self.tab = False
        if tag == "code" and self.code is not None:
            self.example[self.code] = "".join(self.parts)
            self.code = None
        if tag == "div" and self.example is not None:
            self.depth -= 1
            if self.depth == 0:
                if self.example["section"] in SECTIONS:
                    assert "markdown" in self.example and "html" in self.example
                    self.examples.append(self.example)
                self.example = None

    def handle_data(self, data):
        if self.heading is not None:
            self.heading.append(data)
        if self.code is not None:
            self.parts.append(data.replace("→", "\t") if self.tab else data)

parser = Examples()
parser.feed(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert {example["section"] for example in parser.examples} == SECTIONS
output = Path(__file__).resolve().parents[1] / "test/core/spec/fixtures/gfm-0.29-extensions.json"
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(parser.examples, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"Extracted {len(parser.examples)} GFM extension examples")
