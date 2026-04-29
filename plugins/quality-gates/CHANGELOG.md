# Changelog

All notable changes to the `quality-gates` plugin are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [SemVer](https://semver.org/spec/v2.0.0.html).

## [1.5.0] — 2026-04-30

### Added
- Phase 0 `scout` agent: Sonnet, model-driven Gate 2 dispatch planner. Reads filtered diff + Gate 1 summary, emits structured YAML dispatch plan (depth + phase1_agents + phase2_agents + rationale).
- Phase 1.5 `adversarial` agent: Opus, hunts false positives in Phase 1+2 findings (confirm/downgrade/reject verdicts). Strengthens review while reducing fix-loop iterations on noise.
- Phase 1.6 `synthesizer` agent: Sonnet, dedupes/ranks findings (severity × confidence), suppresses confidence < 7, produces user-facing prioritized Markdown.
- `PostToolUse` hook `post-tool-use-session-tracker.py`: accumulates Edit/Write/MultiEdit file paths into `.claude/quality-gates-session.local.md` for `/qg` scope narrowing.
- `SessionStart` hook `session-start-advisor.py`: read-only advisor that surfaces in-flight pipelines without mutation (CLAUDE.md hook-coexistence rule).
- `/qg branch`, `/qg --paths <glob>`, `/qg --reset` flag support.
- `cost_class` declarations on the pipeline skill and all new agents.
- Trivia escape (`scripts/check-trivia.sh`): single-file whitespace/rename ≤3 lines automatically skip the entire pipeline.
- Docs filter (`scripts/filter-docs.sh`): `*.md` / `docs/**` / `CHANGELOG*` / `README*` excluded from code-reviewer scope (Gate 1 plan-verifier still sees raw diff).
- Repeat-detection: identical scout dispatch plan + synthesizer output across two iterations triggers `gate2_repeat_detected` user choice (philosophy AP15 instantiation).
- Gate 1 → Gate 2 handoff format: structured `gate1_summary` YAML block; FAIL halts Gate 2 entry (Law 1).
- AskUserQuestion hard gate when Phase 1+2 dispatch ≥ 4 (philosophy AP9 instantiation).
- Pre-pipeline check (`scripts/pre-pipeline-check.sh`): handles session lifecycle (active resume / branch mismatch / staleness / fresh start).
- New tests under `tests/`: `test_session_tracker.py` (7), `test_session_start_advisor.py` (10), `test_stop_hook_state_machine.py` (6).

### Changed
- Default review scope is now files edited in the current Claude Code session (not full branch diff). Override with `/qg branch` for old behavior.
- Gate 2 Phase 1 fan-out is now depth-aware (1 / 2 / 3 agents instead of always 3) per scout's plan.
- Within-Gate-2 fix-loop now re-runs scout on delta diff each iteration (only files changed since last iteration).
- `total_iterations` and `max_total_iterations` no longer written by `setup-qg.sh`; read by `stop-hook.py` only for backward compatibility with stale state files.
- System message format updated: shows `iter N/M` only for Gate 2; other gates show only gate name.

### Removed
- **Cross-gate restart loop**: Gate 2 / Gate 3 `NEEDS_RESTART` no longer auto-restarts from Gate 1. Now terminates with a user-choice prompt ("apply changes and re-run /qg").
- `MAX_TOTAL_ITERATIONS` constant and the entire `restart` transition from `stop-hook.py` and `setup-qg.sh`.
- Rule-based `SCOPE_*` env-var Phase 2 gating from SKILL.md (replaced by scout's `phase2_agents` field; legacy code retained as fallback when scout fails).

### Fixed
- Gate 1 plan-verifier output format formalized: a structured `gate1_summary` YAML block is required (was free-form prose), enabling deterministic Gate 2 dispatch.
- Stop-hook state machine: `compute_transition` extracted as a pure top-level function (was inline in `main()`); now testable in isolation.

### Security
- All new reviewer agents (`scout`, `adversarial`, `synthesizer`) declare `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` (Law 2 enforcement).

## [1.4.0] — earlier

- Move Gate 2 orchestration into `quality-pipeline` skill (PR #14).

## [1.3.0] — earlier

- Stop-hook-driven pipeline progression + Gate 2 token reduction (PR #12).

## Earlier

- Initial Stop-hook-based pipeline (PR #10), signal-detection fixes (PR #11).
