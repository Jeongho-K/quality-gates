#!/usr/bin/env bash
# AC2 — design 자리의 프로필이 `handoff_incomplete` 를 **층 2 항목으로** 정의하고,
# 그 정의가 `## Handoff Context` 부재를 발화 조건으로 이름 댄다.
#
# ── 앵커 재조준 (문서 리뷰 엔진 전환, T7) ────────────────────────────────────
# 옛 대상은 삭제된 design-doc 리뷰어 agent 였다. 그 agent 는 엔진 전환으로 사라졌고,
# 이 카테고리를 오늘 소유하는 것은 `references/docreview-profiles/design-doc.md` 다.
#
# **승계하지 못한 것 하나를 이름으로 남긴다**: 옛 판정 AC2c 는 이 카테고리의 severity
# 가 `block` 인지를 쟀다. 엔진에는 per-category severity 가 없다 — finding 은
# `disposition`(decide·ask·fix·defer·drop)을 갖고, 「막음」은 `fin.json` 의 `blocks`
# 가 별도 축으로 판정한다. 없어진 개념의 리터럴을 계속 요구하면 이 락은 거짓 인용을
# 강제하는 장치가 되므로, 그 자리를 **층 배치**(층 2 이지 층 1 이 아니다)로 바꾼다.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PROFILE="$REPO_ROOT/plugins/spec-distill/references/docreview-profiles/design-doc.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# 양의 짝 — 대상 부재 위에서 아래 판정이 「없으니 어긋날 것도 없다」로 통과하는 것을 막는다.
if [[ -f "$PROFILE" ]]; then
  ok "AC2: 프로필 실재 — ${PROFILE#"$REPO_ROOT/"}"
else
  no "AC2: 프로필 부재 — ${PROFILE#"$REPO_ROOT/"} (아래 판정은 잴 대상이 없다)"
  finish; exit
fi

LAYER1="$(sed -n 's/^[[:space:]]*layer1:[[:space:]]*//p' "$PROFILE" | head -1)"
LAYER2="$(sed -n 's/^[[:space:]]*layer2:[[:space:]]*//p' "$PROFILE" | head -1)"
if [[ -n "$LAYER1" && -n "$LAYER2" ]]; then
  ok "AC2: layer_rubric 두 목록 추출 성공"
else
  no "AC2: layer_rubric 추출 실패 (layer1='$LAYER1' layer2='$LAYER2') — 프로필 문법이 바뀌었다"
  finish; exit
fi

# AC2a: 카테고리 ID 가 **층 2 목록 안에** 있다.
printf '%s' "$LAYER2" | grep -qF 'handoff_incomplete' \
  && ok "AC2: handoff_incomplete 가 layer_rubric.layer2 에 등재" \
  || no "AC2: handoff_incomplete 가 layer2 목록에 없다"

# AC2c 의 승계 — 층 배치. 층 1 은 큰 그림 정합 축이고 처분이 대개 `decide`(사용자
# 결정)다. handoff 완결성은 저자가 고치는 상세이므로 층 2 여야 한다. 두 목록에
# 동시에 실리면 탐지 리뷰어가 같은 결함을 두 블록으로 내며 층 분리가 무너진다.
printf '%s' "$LAYER1" | grep -qF 'handoff_incomplete' \
  && no "AC2: handoff_incomplete 가 layer1 에도 있다 — 층 분리 붕괴 (층 2 전용이어야 한다)" \
  || ok "AC2: handoff_incomplete 는 layer1 에 없다 (층 2 전용)"

# AC2b: 본문의 층 2 절이 그 카테고리의 발화 조건으로 `Handoff Context` 를 이름 댄다.
# 창을 「## 층 2」 헤딩부터 다음 `## ` 헤딩까지로 자른다 — frontmatter 의 목록 한 줄이
# 이 판정을 혼자 만족시키는 header-satisfiable 함정을 피한다(목록에는 산문이 없다).
BODY2="$(awk '/^## 층 2/{f=1; print; next} f && /^## /{f=0} f' "$PROFILE")"
if [[ -z "$BODY2" ]]; then
  no "AC2: 「## 층 2」 창이 비었다 — 구조 앵커 파손 (통과 아님)"
elif printf '%s' "$BODY2" | grep -qF 'handoff_incomplete' \
     && printf '%s' "$BODY2" | grep -qF 'Handoff Context'; then
  ok "AC2: 층 2 본문이 handoff_incomplete 를 'Handoff Context' 부재와 함께 정의한다"
else
  no "AC2: 층 2 본문에 handoff_incomplete 의 'Handoff Context' 발화 조건이 없다"
fi
finish
