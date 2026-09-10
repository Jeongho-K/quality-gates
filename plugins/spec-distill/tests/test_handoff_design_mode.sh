#!/usr/bin/env bash
# AC7 — design 자리의 층 2 체크리스트에 `handoff_incomplete` 가 일곱 번째로 실려 있다.
#
# ── 앵커 재조준 (문서 리뷰 엔진 전환, T7) ────────────────────────────────────
# 옛 대상은 삭제된 design-doc 리뷰어 agent 의 「Design Mode Branch」 블록이었다.
# 그 agent 는 엔진 전환으로 사라졌고, 이 자리의 체크리스트를 오늘 소유하는 것은
# `references/docreview-profiles/design-doc.md` 의 `layer_rubric.layer2` 다 — 탐지
# 리뷰어(`doc-critic`)가 층 2 에서 그 목록을 그대로 검토 항목으로 쓴다.
#
# 재는 것은 그대로다: **일곱 카테고리가 한 목록 안에 함께 있는가.** 대상만 바뀐다.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PROFILE="$REPO_ROOT/plugins/spec-distill/references/docreview-profiles/design-doc.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# 양의 짝 — 부재 대상 위에서 아래 판정이 조용히 통과하는 것을 막는다. 대상 파일이
# 없으면 `layer2` 추출이 빈 문자열이 되고, 빈 문자열에 대한 grep 은 전부 실패해
# "일곱 개가 없다"라는 **원인을 잘못 짚는** 진단으로 넘어간다.
if [[ -f "$PROFILE" ]]; then
  ok "AC7: 프로필 실재 — ${PROFILE#"$REPO_ROOT/"}"
else
  no "AC7: 프로필 부재 — ${PROFILE#"$REPO_ROOT/"} (아래 판정은 잴 대상이 없다)"
  finish; exit
fi

# `layer_rubric.layer2` 한 줄을 frontmatter 에서 뽑는다. 이 키는 파일 안에 한 번만
# 나오므로 창을 따로 자르지 않는다.
LAYER2="$(sed -n 's/^[[:space:]]*layer2:[[:space:]]*//p' "$PROFILE" | head -1)"
if [[ -n "$LAYER2" ]]; then
  ok "AC7: layer_rubric.layer2 추출 성공 ($LAYER2)"
else
  no "AC7: layer_rubric.layer2 를 추출하지 못했다 — 프로필 문법이 바뀌었거나 키가 사라졌다"
  finish; exit
fi

for cat in "placeholder" "ambiguity" "scope_creep" "approaches_comparison" "isolation" "testing" "handoff_incomplete"; do
  printf '%s' "$LAYER2" | grep -qF "$cat" \
    && ok "AC7: 층 2 카테고리 '$cat' 실재" \
    || no "AC7: 층 2 카테고리 '$cat' 부재"
done
finish
