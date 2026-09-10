#!/usr/bin/env bash
# AC4 — 「대화 컨텍스트 의존」 축이 design 자리에서 살아 있는가: 저자에게 그것을
# 금지하는 지시(템플릿)와, 리뷰어에게 그것을 찾으라는 rubric(프로필) 양쪽에.
#
# ── 앵커 재조준 (문서 리뷰 엔진 전환, T7) ────────────────────────────────────
# 옛 판정은 삭제된 design-doc 리뷰어 agent 안에 C8 conversation-reference 패턴 **15개**
# (영어 8 · 한국어 7)가 리터럴로 열거돼 있는지를 셌다. 그 agent 는 엔진 전환으로
# 사라졌고, **그 열거는 어디로도 승계되지 않았다** — 엔진의 탐지 리뷰어는 프로필의
# 산문 rubric 하나로 판단한다(설계가 정한 능력 축소이고, 이 락이 뒤집지 않는다).
#
# 그러므로 이 파일은 「15개 리터럴」이 아니라 **그 열거가 지키던 성질**을 잰다: 문서가
# `/compact` 뒤에 자기만으로 읽히는가. 그 성질이 살아 있는 자리는 둘이고 둘 다 잰다 —
# 한쪽만 재면 다른 쪽이 조용히 지워진다.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
TPL="$SD/templates/spec-template.md"
PROFILE="$SD/references/docreview-profiles/design-doc.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

for f in "$TPL" "$PROFILE"; do
  [[ -f "$f" ]] && ok "AC4: 대상 실재 — ${f#"$REPO_ROOT/"}" \
                || { no "AC4: 대상 부재 — ${f#"$REPO_ROOT/"}"; finish; exit; }
done

# (1) 저자 쪽 — 템플릿의 Handoff Context 절이 대화 컨텍스트 가정을 금지한다.
WIN="$(awk '/^## Handoff Context/{f=1; print; next} f && /^## /{f=0} f' "$TPL")"
if [[ -z "$WIN" ]]; then
  no "AC4: 템플릿의 '## Handoff Context' 창이 비었다 — 구조 앵커 파손 (통과 아님)"
elif printf '%s' "$WIN" | grep -qE '대화 컨텍스트를 가정하지|self-contained'; then
  ok "AC4: 템플릿이 저자에게 대화 컨텍스트 가정을 금지한다"
else
  no "AC4: 템플릿 Handoff Context 절에서 '대화 컨텍스트 가정 금지' 지시가 사라졌다"
fi

# (2) 리뷰어 쪽 — 프로필 층 2 의 `handoff_incomplete` rubric 이 그 결함을 찾으라고 한다.
# 창은 「## 층 2」 절이다. frontmatter 의 카테고리 목록 한 줄로는 만족되지 않는다
# (그 줄에는 산문이 없다) — header-satisfiable 회피.
BODY2="$(awk '/^## 층 2/{f=1; print; next} f && /^## /{f=0} f' "$PROFILE")"
if [[ -z "$BODY2" ]]; then
  no "AC4: 프로필의 '## 층 2' 창이 비었다 — 구조 앵커 파손 (통과 아님)"
else
  RUBRIC="$(printf '%s\n' "$BODY2" | grep -F 'handoff_incomplete' | head -1)"
  if [[ -z "$RUBRIC" ]]; then
    no "AC4: 층 2 본문에 handoff_incomplete rubric 줄이 없다"
  elif printf '%s' "$RUBRIC" | grep -qF '/compact' \
       && printf '%s' "$RUBRIC" | grep -qE '암묵 컨텍스트|implicit context'; then
    ok "AC4: 프로필 rubric 이 '/compact 뒤 남은 암묵 컨텍스트'를 발화 조건으로 이름 댄다"
  else
    no "AC4: handoff_incomplete rubric 이 대화 컨텍스트 의존 축을 잃었다 ($RUBRIC)"
  fi
fi
finish
