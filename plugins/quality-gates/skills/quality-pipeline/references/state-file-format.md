# State File Format

The state file `.claude/quality-gates.local.md` is managed entirely by the setup
script (`scripts/setup-qg.sh`) and the Stop hook (`hooks/stop-hook.py`).
**The SKILL.md must NOT read or write this file.**

## Schema

```yaml
---
status: gate1_running          # gate1_running | gate2_running | gate3_running | completed | aborted
current_gate: 1                # 1 | 2 | 3
total_iterations: 1            # Full pipeline restart count
gate2_iteration: 0             # Review-fix cycle count within Gate 2
max_total_iterations: 5        # Limit for full pipeline restarts
max_gate2_iterations: 5        # Limit for Gate 2 review-fix cycles
skip_runtime: false            # Whether to skip Gate 3
single_gate: null              # null | gate1 | gate2 | gate3
plan_file: "auto"              # Plan file path or "auto"
pr_url: ""                     # PR URL or empty
available_plugins: "pr-review-toolkit,feature-dev,superpowers"
session_id: "<session_id>"     # For session isolation
started_at: "<ISO timestamp>"  # Pipeline start time
---

# Quality Gates Pipeline State

## Gate Results

### Gate 1
**Verdict:** PASS
**Summary:** 24/24 items implemented (100%)

### Gate 2 Iteration 1
**Verdict:** FAIL
**Summary:** 3 critical issues found, 2 fixed
**Files Changed:** src/auth.ts, src/utils.ts

### Gate 2 Iteration 2
**Verdict:** NEEDS_RESTART
**Summary:** All issues resolved, code changed
**Files Changed:** src/auth.ts

## Pipeline History
- [2026-04-12T10:00:00Z] Pipeline started (iteration 1)
- [2026-04-12T10:02:00Z] Gate 1: PASS
- [2026-04-12T10:05:00Z] Gate 2 iter 1: FAIL
- [2026-04-12T10:08:00Z] Gate 2 iter 2: NEEDS_RESTART
- [2026-04-12T10:08:00Z] Restarting from Gate 1 (iteration 2)
```

## Lifecycle

1. **Created by**: `scripts/setup-qg.sh` (on `/qg`)
2. **Updated by**: `hooks/stop-hook.py` (after each gate completes)
3. **Deleted by**: `hooks/stop-hook.py` (on pipeline complete/abort) or `/cancel-qg`

## Purpose

- Track pipeline progress across Stop hook iterations
- Store gate results for inter-gate context passing
- Session isolation (prevent cross-session interference)
