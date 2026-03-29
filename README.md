# Quality Gates Plugin

3-gate quality verification pipeline for Claude Code.

## Gates

| Gate | Agent | Purpose |
|------|-------|---------|
| 1 | plan-verifier | Cross-references plan checkboxes with git diff |
| 2 | pr-reviewer | Orchestrates pr-review-toolkit agents iteratively |
| 3 | runtime-verifier | Starts the app, checks console errors, takes screenshots |

## Prerequisites

- **pr-review-toolkit** plugin (required for Gate 2)
- **chrome-devtools-mcp** or **playwright** plugin (required for Gate 3)

## Usage

**Manual:** `/qg` or `/qg gate2` or `/qg --skip-runtime`

**Auto-trigger:** Creates PR with `gh pr create` -> hook injects pipeline automatically.

## Configuration

- `MAX_TOTAL_ITERATIONS`: 5 (full pipeline restarts)
- `MAX_GATE2_ITERATIONS`: 3 (review-fix cycles within Gate 2)

## State File

Pipeline state is tracked in `.claude/quality-gates.local.md` (auto-created, auto-deleted).
