#!/usr/bin/env bash
# AC3 — Handoff Context 의 세 하위 항목(TL;DR / Implicit context / Deferred to plan)이
# design doc 의 구조로 실재하고, design 자리 프로필의 `defer_target` 이 그중 셋째를
# 이름으로 가리킨다.
#
# ── 앵커 재조준 (문서 리뷰 엔진 전환, T7) ────────────────────────────────────
# 옛 대상은 삭제된 design-doc 리뷰어 agent 였다 — 그것이 세 라벨을 열거하고 하나라도
# 비면 `handoff_incomplete` 를 냈다. agent 는 사라졌고 엔진의 탐지 리뷰어는 라벨을
# 열거하지 않는다(프로필의 산문 rubric 하나로 판단한다).
#
# 그래서 재는 대상을 **세 라벨을 오늘 실제로 소유하는 자리**로 옮긴다:
#   · `templates/spec-template.md` — design doc 이 이 세 항목으로 쓰인다는 사실의 출처.
#   · `references/docreview-profiles/design-doc.md` 의 `defer_target` — 엔진이 `defer`
#     처분을 실제로 적어 넣는 자리이고, 그 heading 이 셋째 라벨과 같은 이름이어야
#     한다. 이름이 갈라지면 `defer` 가 문서에 없는 절을 가리킨다.
#
# **승계하지 못한 것**: 「하위 항목이 비었는지」를 재던 검출 로직(label 이후 10자 미만)
# 은 엔진에 없다. 그 판단은 이제 `doc-critic` 의 산문 rubric 이 진다 — 리터럴이 없으므로
# 기계적으로 잴 수 없고, 없어진 리터럴을 계속 요구하지 않는다.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
TPL="$SD/templates/spec-template.md"
PROFILE="$SD/references/docreview-profiles/design-doc.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# 양의 짝 — 두 대상이 실재하고 읽혔는가. 없으면 아래 존재 단언은 전부 「없으니
# 어긋날 것도 없다」가 아니라 원인을 잘못 짚는 실패로 나온다.
for f in "$TPL" "$PROFILE"; do
  [[ -f "$f" ]] && ok "AC3: 대상 실재 — ${f#"$REPO_ROOT/"}" \
                || { no "AC3: 대상 부재 — ${f#"$REPO_ROOT/"}"; finish; exit; }
done

# 템플릿의 `## Handoff Context` 절만 창으로 자른다 — 파일 어딘가에 라벨이 있으면
# 통과하는 것이 아니라 **그 절 안에** 있어야 한다.
WIN="$(awk '/^## Handoff Context/{f=1; print; next} f && /^## /{f=0} f' "$TPL")"
if [[ -z "$WIN" ]]; then
  no "AC3: 템플릿의 '## Handoff Context' 창이 비었다 — 구조 앵커 파손 (통과 아님)"
  finish; exit
fi
ok "AC3: 템플릿 Handoff Context 창 추출 ($(printf '%s\n' "$WIN" | wc -l | tr -d ' ')줄)"

for label in "TL;DR" "Implicit context" "Deferred to plan"; do
  printf '%s' "$WIN" | grep -qF "$label" \
    && ok "AC3: 하위 항목 '$label' 이 템플릿 Handoff Context 절에 실재" \
    || no "AC3: 하위 항목 '$label' 이 템플릿 Handoff Context 절에 없다"
done

# 프로필의 defer 착지점이 셋째 라벨과 같은 이름인가.
DEFER="$(sed -n 's/^[[:space:]]*defer_target:[[:space:]]*//p' "$PROFILE" | head -1)"
if [[ -z "$DEFER" ]]; then
  no "AC3: 프로필에서 defer_target 을 추출하지 못했다"
elif printf '%s' "$DEFER" | grep -qF 'Deferred to plan'; then
  ok "AC3: 프로필 defer_target 이 'Deferred to plan' 을 이름으로 가리킨다 ($DEFER)"
else
  no "AC3: 프로필 defer_target 이 템플릿의 셋째 라벨과 다른 이름이다 ($DEFER) — defer 가 문서에 없는 절로 간다"
fi
finish
