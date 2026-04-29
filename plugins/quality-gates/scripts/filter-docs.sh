#!/usr/bin/env bash
# Filter docs paths from a newline-separated path list (stdin → stdout).
# (qg-cost-reduction plan §D)
#
# Excluded: *.md, *.txt, *.rst, docs/**, CHANGELOG*, README*

set -euo pipefail

while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  case "$path" in
    *.md|*.txt|*.rst) continue ;;
    docs/*|*/docs/*) continue ;;
    CHANGELOG*|*/CHANGELOG*) continue ;;
    README*|*/README*) continue ;;
  esac
  printf '%s\n' "$path"
done
