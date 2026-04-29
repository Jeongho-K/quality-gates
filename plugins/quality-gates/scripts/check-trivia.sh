#!/usr/bin/env bash
# Trivia escape detector. (qg-cost-reduction plan §E)
#
#   exit 0 + stdout "trivia: <kind>"  → skip pipeline
#   exit 1                            → not trivia (run pipeline)
#
# Conservative: only whitespace-only OR rename-only with ≤3 lines and 1 file.
# Comment-only is intentionally NOT detected (language-fragility risk).

set -euo pipefail

paths=()
if [[ $# -gt 0 && "$1" == "--paths" ]]; then
  shift
  paths=("$@")
fi

# Helper: invoke git diff HEAD with optional pathspec.
# HEAD baseline captures both staged and unstaged changes; required for
# rename detection (git mv stages the rename, plain `git diff` misses it).
gd() {
  if [[ ${#paths[@]} -gt 0 ]]; then
    git diff HEAD "$@" -- "${paths[@]}"
  else
    git diff HEAD "$@"
  fi
}

file_count="$(gd --name-only | wc -l | tr -d ' ')"
if [[ "$file_count" != "1" ]]; then
  exit 1
fi

# Sum insertions + deletions from --shortstat
line_count="$(gd --shortstat 2>/dev/null \
  | grep -oE '[0-9]+ (insertion|deletion)' \
  | awk '{s+=$1} END {print s+0}')"
if [[ "$line_count" -gt 3 ]]; then
  exit 1
fi

# Whitespace-only?
if [[ -z "$(gd -w)" ]]; then
  echo "trivia: whitespace"
  exit 0
fi

# Rename-only?
renames="$(gd --diff-filter=R --name-only | wc -l | tr -d ' ')"
content_changes="$(gd --name-only --diff-filter=ACMD | wc -l | tr -d ' ')"
if [[ "$renames" -ge 1 && "$content_changes" -eq 0 ]]; then
  echo "trivia: rename"
  exit 0
fi

exit 1
