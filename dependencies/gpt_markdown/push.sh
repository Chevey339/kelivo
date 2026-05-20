#!/bin/bash
set -e
git add -A
git diff --cached --quiet || git commit -m "${1:-Update}"
git push https://x-access-token:$GITHUB_PERSONAL_ACCESS_TOKEN@github.com/Infinitix-LLC/gpt_markdown.git main
