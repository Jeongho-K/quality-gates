#!/usr/bin/env bash
# PN2/V8/AC10 — reviewing-spec is design-mode only; spec-mode/re-consensus/Mode B removed;
# drafting-spec absent from skills/hooks/commands.
#
# ── 앵커 재조준 (문서 리뷰 엔진 전환) ────────────────────────────────────────
# 이 파일의 두 **양의** 단언은 옛 라우팅 표의 두 행(`design | approved | … Human Gate`,
# `design | needs_revise | … author 회귀`)을 잡고 있었다. 그 표는 verdict 어휘 위에
# 서 있었는데, 껍데기화로 verdict 자체가 사라졌다 — 라우팅은 이제 `docreview_route.py
# finalize` 의 처분 회계가 하고 표는 없다. 없어진 문자열을 계속 요구하면 이 락은
# **거짓 인용을 강제**하는 장치가 된다(삭제된 규칙이 남기는 거짓 인용).
#
# 그래서 파일을 지우지 않고 두 양의 단언만 재조준한다. 이 파일의 주제 — *"이 skill 은
# design 자리 전용인가"* — 는 껍데기에서도 그대로 참이고, 그 주제를 오늘 지탱하는 것은
# 표가 아니라 **프로필 선택**이다: 이 skill 은 `design-doc.md` 하나만 고르고, 훅이 내는
# `mode:` 두 값(`design`·`spec`)이 그 하나로 모인다. 그 매핑이 갈라지는 순간 이 skill 은
# design 전용이 아니게 된다.
#
# 아래 **부재** 단언 넷(re-consensus · mode_b_violation · spec-mode 표 행 · drafting-spec)
# 은 손대지 않는다 — 그것들이 잠그는 개념은 껍데기에서도 여전히 되살아나면 안 된다.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PLUGIN="$REPO_ROOT/plugins/spec-distill"
SKILL="$PLUGIN/skills/reviewing-spec/SKILL.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# (1) 이 skill 이 고르는 프로필은 design-doc 하나다.
grep -qF 'references/docreview-profiles/design-doc.md' "$SKILL" \
  && ok "design-doc 프로필을 이름으로 고른다" \
  || no "design-doc 프로필 선택이 사라졌다 — 이 skill 이 어느 자리인지 문서가 말하지 않는다"

# (2) 훅이 내는 `mode:` 두 값이 **그 하나로 모인다**는 주장이 실재하는가.
#
# 〔fix round 1 / I-1〕 앞 판본은 `'design.*spec.*design-doc\.md|`design`.*`spec`'` 였고
# **헤더-satisfiable** 이었다: 매핑 문장 바로 위의 «관찰» 한 줄(*"값역은 `design`·`spec` 인데
# 프로필 파일 이름은 `design-doc.md` 다 — 이름이 다르다"*)이 혼자 그 패턴을 만족시킨다.
# 실측 두 갈래로 확인된 구멍이다 —
#   · 매핑 줄을 「`design` 은 `design-doc.md` 로, `spec` 은 `spec-doc.md` 로 간다」로 바꿔도 GREEN
#     (= 실패 문면이 이름 대는 바로 그 결함이 통과한다)
#   · 매핑 줄만 지우고 관찰 줄을 남겨도 GREEN
# 내 mutation 이 세 줄을 «한 덩어리로» 지운 탓에 그 구멍이 가려졌다(변이가 락의 전제를 공유했다).
#
# 그래서 판정을 **수렴 주장 자체**로 옮긴다. 한 줄 안에 두 값 + 수렴어 + 그 프로필이 모두
# 있어야 한다 — 관찰 줄에는 수렴어가 없으므로 그 줄로는 만족되지 않는다(body-unique).
CONVERGE='`design`.*`spec`.*(같은|둘 다|모두|전부).*design-doc\.md'
if grep -qE "$CONVERGE" "$SKILL"; then
  ok "mode 매핑: 한 줄이 design·spec 두 값의 «같은 design-doc 프로필로 수렴»을 주장한다"
else
  no "mode 매핑 수렴 주장이 한 줄 안에 없다 — 두 값이 갈라져도(예: spec → 다른 프로필) 이 락이 침묵한다. 요구: 한 줄에 \`design\` · \`spec\` · 수렴어(같은/둘 다/모두/전부) · design-doc.md"
fi

# (2b) 위 (2)는 «주장»을 재고, 이 축은 «사실»을 잰다: 실재하는 프로필 파일 중 이 skill 이
#      이름 대는 것이 design-doc 하나뿐인가. 대상은 열거가 아니라 프로필 디렉터리에서
#      도출한다 — 넷째 프로필이 생기면 자동으로 이 축에 들어온다.
PROF_DIR="$PLUGIN/references/docreview-profiles"
prof_n=0
named_other=""
for _pf in "$PROF_DIR"/*.md; do
  [[ -f "$_pf" ]] || continue
  prof_n=$((prof_n + 1))
  _b="$(basename -- "$_pf")"
  [[ "$_b" == "design-doc.md" ]] && continue
  grep -qF -- "$_b" "$SKILL" && named_other="$named_other $_b"
done
if [[ "$prof_n" -lt 2 ]]; then
  no "(2b) 프로필 디렉터리에서 ${prof_n}개만 도출 — 「design-doc 말고 다른 것을 안 부른다」가 이 상태에서 공허하다"
elif [[ -z "$named_other" ]]; then
  ok "(2b) 실재 프로필 ${prof_n}개 중 이 skill 이 이름 대는 것은 design-doc 하나뿐이다"
else
  no "(2b) 이 skill 이 design-doc 아닌 프로필을 이름 댄다:$named_other — design 전용이 아니게 된다"
fi

grep -qiE 'reconsensus|re-consensus|\[3\.5\]' "$SKILL" \
  && no "re-consensus gate still present (should be removed)" \
  || ok "re-consensus [3.5] removed"
grep -qE 'mode_b_violation' "$SKILL" \
  && no "mode_b_violation still present" || ok "mode_b_violation removed"
grep -qE '^\|[[:space:]]*\**[[:space:]]*spec\b' "$SKILL" \
  && no "spec-mode routing rows still present" || ok "spec-mode routing rows removed"
grep -q 'drafting-spec' "$SKILL" \
  && no "drafting-spec still referenced in reviewing-spec" || ok "drafting-spec ref removed from reviewing-spec"

# F9-D: scan agents/ + templates/ too — the exact dirs an earlier PR cleaned of
# drafting-spec/Mode-B refs (design 자리 리뷰어 persona · spec-template comment).
# 그 persona 파일은 문서 리뷰 엔진 전환(T7)으로 사라졌지만 두 디렉토리는 여전히
# 스캔 루트다 — 코퍼스를 좁히면 이 부재 단언이 조용히 약해진다.
# Task 33: `$PLUGIN/references` (플러그인 레벨 공유 계약, skills/ 밖) 도 스캔 루트다.
#
# 〔fix round 1 / F4〕 루트를 덧붙이기만 하면 오타·개명 시 `grep -r` 의 *No such file* 이
# `2>/dev/null` 에 삼켜지고, 이 **부재** 단언은 좁아진 코퍼스 위에서 통과한다(조용한 축소).
# 열거한 루트가 전부 실재하는지 먼저 잰다.
F9D_ROOTS=("$PLUGIN/skills" "$PLUGIN/hooks" "$PLUGIN/commands" \
  "$PLUGIN/agents" "$PLUGIN/templates" "$PLUGIN/references")
for _r in "${F9D_ROOTS[@]}"; do
  [[ -d "$_r" ]] \
    && ok "AC10/F9-D: 스캔 루트 실재 — ${_r#"$PLUGIN/"}" \
    || no "AC10/F9-D: 스캔 루트 '${_r#"$PLUGIN/"}' 부재 — grep -r 이 그 코퍼스를 조용히 건너뛴다"
done
COUNT=$(grep -rl 'drafting-spec' "${F9D_ROOTS[@]}" 2>/dev/null | wc -l | tr -d ' ')
[[ "$COUNT" == "0" ]] && ok "AC10/F9-D: 0 drafting-spec refs in skills/hooks/commands/agents/templates" \
  || no "AC10/F9-D: $COUNT drafting-spec refs remain"
[[ ! -d "$PLUGIN/skills/drafting-spec" ]] && ok "drafting-spec/ directory removed" \
  || no "drafting-spec/ directory still exists"
finish
