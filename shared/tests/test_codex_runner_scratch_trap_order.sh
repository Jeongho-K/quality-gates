#!/usr/bin/env bash
# codex 러너의 **순서 불변식 셋** — 도출된 러너 전부에.
#
# ── 왜 이 파일이 생겼는가 (T7 재리뷰 F-1) ────────────────────────────────────
# 이 축은 삭제된 `test_run_spec_codex_reviewer.sh` 안에 **러너 하나 몫으로만** 살아
# 있었다. 그 파일이 지워지면서 축이 통째로 사라졌고, 리포 전체에 승계처가 없었다
# (실측 스윕: `plugins/*/tests/*` · `shared/tests/*` 에 어떤 러너에 대해서도 후속 락
# 0건). 성질 자체는 오늘 모든 러너에서 지켜지고 있다 — 없어진 것은 **회귀 락**이고,
# 그래서 트랩을 대입 위로 옮기는 편집이 지금은 스위트 전량을 통과한다.
#
# 한 러너에 하드코딩해 되살리면 같은 일이 다시 일어난다. 대상은 **도출**한다.
#
# ── 축 A: `rm -rf "$SCRATCH"` 트랩보다 가드된 대입이 먼저다 (C7) ─────────────
# `mktemp` 가 실패했는데 트랩이 이미 무장돼 있으면 `rm -rf ""` 가 돈다. 이 리포에는
# 그 사고의 실제 기록이 있고(`/tmp`→`/private/tmp` 경로 붕괴로 무관한 RED 14건),
# `shared/docreview/scripts/run_docreview_codex_reviewer.sh` 의 주석이 그 위험을
# 이름으로 부르고 있다 — 코드는 기억하는데 테스트가 잊은 상태였다.
#
# **트랩에 `rm -rf "$SCRATCH"` 가 없는 러너는 이 축의 대상이 아니다**(qg 두 러너는
# EXIT 트랩이 `_degrade_if_empty` 만 부른다 — 지울 대상이 없으니 footgun 도 없다).
# 그 면제를 조용히 넘기지 않는다: 대상/면제를 둘 다 세어 출력하고, 대상이 0 이 되면
# 이 축이 공허하므로 RED 다.
#
# ── 축 B: 상대 경로 절대화가 `cd "$PROJECT_DIR"` 보다 먼저다 (FIX2) ──────────
# 뒤에 오면 호출자가 준 상대 산출물 경로가 project_dir 기준으로 조용히 재해석된다.
#
# ── 축 C: `CLAUDE_PLUGIN_ROOT` 는 fallback 과 함께 쓴다 (FALLBACK) ───────────
# 훅 실행에만 주입되는 변수라 맨 `${CLAUDE_PLUGIN_ROOT}` 참조는 `set -u` 아래
# 스킬의 bash 블록에서 codex 에 닿기 전에 즉사한다.
set -u -o pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"

# ── 도출 ────────────────────────────────────────────────────────────────────
# 배포 사본이 아니라 **파일**을 센다. `run_docreview_codex_reviewer.sh` 는 정본 하나에
# 배포 심볼릭 링크 둘이라 경로로는 셋인데 실체는 하나다 — realpath 로 접어야 같은
# 파일을 세 번 재고 「대상 8곳」이라고 부풀리는 일이 없다(T6b 가 밟은 바로 그 함정).
CAND_RAW="$(git ls-files -- \
  'plugins/*/scripts/run_*codex*.sh' \
  'shared/*/scripts/run_*.sh' \
  'shared/codex/run_*.sh' 2>/dev/null | sort)"

RUNNERS=""
seen=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -f "$f" ] || continue
  rp="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$f")"
  case " $seen " in *" $rp "*) continue ;; esac
  seen="$seen $rp"
  RUNNERS="$RUNNERS${RUNNERS:+
}$f"
done <<EOF_CAND
$CAND_RAW
EOF_CAND

n_run=0
[ -n "$RUNNERS" ] && n_run="$(printf '%s\n' "$RUNNERS" | grep -c .)"
if [ "$n_run" -ge 4 ]; then
  ok "도출: 서로 다른 러너 ${n_run}개 (배포 링크 접은 뒤 — vacuous 아님)"
  printf '%s\n' "$RUNNERS" | sed 's/^/      /'
else
  no "도출: 러너가 ${n_run}개뿐 — 도출 기준(pathspec/realpath 접기)이 깨졌다. 아래 세 축은 이 상태에서 공허하다"
  finish; exit
fi

# ── 축 A ────────────────────────────────────────────────────────────────────
a_subject=0
a_exempt=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  trap_line="$(grep -nE '^[[:space:]]*trap .*rm -rf .*\$\{?SCRATCH.*EXIT' "$f" | head -1 | cut -d: -f1)"
  if [ -z "$trap_line" ]; then
    a_exempt="$a_exempt ${f##*/}"
    continue
  fi
  a_subject=$((a_subject + 1))
  guard_line="$(grep -nE 'SCRATCH=.*mktemp.*\|\|' "$f" | head -1 | cut -d: -f1)"
  if [ -z "$guard_line" ]; then
    no "축 A: ${f##*/} — \`rm -rf \"\$SCRATCH\"\` 트랩(:$trap_line)은 있는데 가드된 mktemp 대입이 없다 (C7 footgun)"
  elif [ "$guard_line" -lt "$trap_line" ]; then
    ok "축 A: ${f##*/} — 가드된 대입(:$guard_line) 이 트랩 무장(:$trap_line) 보다 앞선다"
  else
    no "축 A: ${f##*/} — 트랩(:$trap_line) 이 가드된 대입(:$guard_line) 보다 **먼저** 무장한다 — mktemp 실패 시 \`rm -rf \"\"\` 가 돈다"
  fi
done <<EOF_A
$RUNNERS
EOF_A
if [ "$a_subject" -ge 1 ]; then
  ok "축 A: 대상 ${a_subject}개 (면제:${a_exempt:- 없음} — 트랩이 SCRATCH 를 지우지 않는 러너)"
else
  no "축 A: 대상이 0개다 — 어떤 러너도 \`rm -rf \"\$SCRATCH\"\` 트랩을 갖지 않아 이 축이 공허하다 (정규식이 트랩 문법과 어긋났을 가능성부터 본다). 면제:${a_exempt:- 없음}"
fi

# ── 축 B ────────────────────────────────────────────────────────────────────
b_subject=0
b_exempt=""
while IFS= read -r f; do
  [ -n "$f" ] || continue
  cd_line="$(grep -nE '^[[:space:]]*cd "\$PROJECT_DIR"' "$f" | head -1 | cut -d: -f1)"
  if [ -z "$cd_line" ]; then
    b_exempt="$b_exempt ${f##*/}"
    continue
  fi
  b_subject=$((b_subject + 1))
  abs_line="$(grep -nF '"$PWD/$' "$f" | head -1 | cut -d: -f1)"
  if [ -z "$abs_line" ]; then
    no "축 B: ${f##*/} — \`cd \"\$PROJECT_DIR\"\`(:$cd_line) 은 있는데 상대 경로 절대화가 없다"
  elif [ "$abs_line" -lt "$cd_line" ]; then
    ok "축 B: ${f##*/} — 절대화(:$abs_line) 가 cd(:$cd_line) 보다 앞선다"
  else
    no "축 B: ${f##*/} — 절대화(:$abs_line) 가 cd(:$cd_line) 뒤다 — 상대 산출물 경로가 project_dir 기준으로 조용히 재해석된다"
  fi
done <<EOF_B
$RUNNERS
EOF_B
if [ "$b_subject" -ge 1 ]; then
  ok "축 B: 대상 ${b_subject}개 (면제:${b_exempt:- 없음} — project_dir 로 cd 하지 않는 러너)"
else
  no "축 B: 대상이 0개다 — 이 축이 공허하다. 면제:${b_exempt:- 없음}"
fi

# ── 축 C ────────────────────────────────────────────────────────────────────
while IFS= read -r f; do
  [ -n "$f" ] || continue
  if grep -qF '${CLAUDE_PLUGIN_ROOT:-' "$f"; then
    ok "축 C: ${f##*/} — CLAUDE_PLUGIN_ROOT 를 fallback 과 함께 쓴다"
  else
    no "축 C: ${f##*/} — \${CLAUDE_PLUGIN_ROOT:-…} fallback 이 없다 (훅 밖 실행에서 set -u 즉사)"
  fi
  bare="$(grep -nE '\$\{CLAUDE_PLUGIN_ROOT\}' "$f" | head -1)"
  if [ -z "$bare" ]; then
    ok "축 C: ${f##*/} — 맨 \${CLAUDE_PLUGIN_ROOT} 참조 없음 (음의 짝)"
  else
    no "축 C: ${f##*/} — 맨 \${CLAUDE_PLUGIN_ROOT} 참조가 남아 있다: $bare"
  fi
done <<EOF_C
$RUNNERS
EOF_C
finish
