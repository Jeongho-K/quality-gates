# 변경 로그

`quality-gates` 플러그인의 주요 변경 사항을 기록합니다.
포맷은 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), 버전 규칙은 [SemVer](https://semver.org/spec/v2.0.0.html) 를 따릅니다.

## [1.5.0] — 2026-04-30

### Added
- Phase 0 `scout` agent: Sonnet, 모델 기반 Gate 2 dispatch planner. 필터링된 diff + Gate 1 summary 를 읽어 구조화된 YAML dispatch plan (depth + phase1_agents + phase2_agents + rationale) 을 생성.
- Phase 1.5 `adversarial` agent: Opus, Phase 1+2 finding 의 false positive 사냥 (confirm/downgrade/reject 판정). 노이즈에 의한 fix-loop 반복을 줄이며 리뷰를 강화.
- Phase 1.6 `synthesizer` agent: Sonnet, finding 을 dedupe/rank (severity × confidence), confidence < 7 suppress, 사용자에게 보일 prioritized Markdown 산출.
- `PostToolUse` hook `post-tool-use-session-tracker.py`: Edit/Write/MultiEdit 파일 경로를 `.claude/quality-gates-session.local.md` 에 누적해 `/qg` scope 을 좁힘.
- `SessionStart` hook `session-start-advisor.py`: 변경 없는 read-only advisor — in-flight 파이프라인을 알림 (CLAUDE.md hook coexistence 룰 준수).
- `/qg branch`, `/qg --paths <glob>`, `/qg --reset` flag 지원.
- pipeline skill 과 모든 신규 agent 에 `cost_class` 선언.
- Trivia escape (`scripts/check-trivia.sh`): 단일 파일·≤3 줄 whitespace/rename 시 파이프라인 전체 자동 스킵.
- Docs 필터 (`scripts/filter-docs.sh`): `*.md` / `docs/**` / `CHANGELOG*` / `README*` 를 코드 리뷰어 scope 에서 제외 (Gate 1 plan-verifier 는 raw diff 를 그대로 봄).
- Repeat-detection: 두 iteration 연속으로 scout dispatch plan + synthesizer 출력이 동일하면 `gate2_repeat_detected` user choice 발동 (philosophy AP15 인스턴스화).
- Gate 1 → Gate 2 핸드오프 포맷: 구조화된 `gate1_summary` YAML 블록; FAIL 시 Gate 2 진입 차단 (Law 1).
- Phase 1+2 dispatch 수가 ≥4 일 때 AskUserQuestion 하드 게이트 (philosophy AP9 인스턴스화).
- Pre-pipeline check (`scripts/pre-pipeline-check.sh`): 세션 라이프사이클 처리 (active resume / branch mismatch / staleness / fresh start).
- `tests/` 신규 테스트: `test_session_tracker.py` (7), `test_session_start_advisor.py` (10), `test_stop_hook_state_machine.py` (6).

### Changed
- 기본 리뷰 scope 이 풀 브랜치 diff 가 아니라 **현재 Claude Code 세션에서 편집한 파일들** 로 변경. 기존 동작은 `/qg branch` 로 사용.
- Gate 2 Phase 1 fan-out 이 scout 의 plan 에 따라 depth 별로 다름 (1 / 2 / 3 agent; 더 이상 항상 3 개 아님).
- Gate 2 내부 fix-loop 가 매 iteration 마다 delta diff (이전 iter 이후 변경된 파일만) 로 scout 을 재실행.
- `total_iterations` 와 `max_total_iterations` 는 더 이상 `setup-qg.sh` 가 작성하지 않음; `stop-hook.py` 는 stale state 파일 호환을 위해 읽기만 함.
- 시스템 메시지 포맷 갱신: `iter N/M` 은 Gate 2 만 표시; 다른 게이트는 게이트 이름만 표시.

### Removed
- **Cross-gate restart 루프**: Gate 2 / Gate 3 `NEEDS_RESTART` 가 더 이상 Gate 1 으로 자동 재진입하지 않음. user-choice prompt ("변경을 적용하고 /qg 재실행") 로 종료.
- `MAX_TOTAL_ITERATIONS` 상수 와 `restart` transition 을 `stop-hook.py` 와 `setup-qg.sh` 양쪽에서 모두 제거.
- SKILL.md 의 룰 기반 `SCOPE_*` env-var Phase 2 게이팅 제거 (scout 의 `phase2_agents` 필드로 대체; scout 실패 시 fallback 으로 레거시 코드 유지).

### Fixed
- Gate 1 plan-verifier 출력 포맷 표준화: 구조화된 `gate1_summary` YAML 블록 필수 (이전엔 자유 산문). 결정론적 Gate 2 dispatch 가능.
- Stop-hook state machine: `compute_transition` 을 top-level 순수 함수로 추출 (이전엔 `main()` 안에 inline). 단위 테스트 가능.

### Security
- 모든 신규 리뷰어 agent (`scout`, `adversarial`, `synthesizer`) 가 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` 선언 (Law 2 강제).

## [1.4.0] — 이전

- Gate 2 orchestration 을 `quality-pipeline` skill 안으로 이동 (PR #14).

## [1.3.0] — 이전

- Stop-hook 기반 파이프라인 진행 + Gate 2 토큰 절감 (PR #12).

## 그 이전

- 초기 Stop-hook 기반 파이프라인 (PR #10), 시그널 검출 수정 (PR #11).
