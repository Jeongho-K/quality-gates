---
name: quality-pipeline
description: >
  Run the 3-gate quality verification pipeline. Use when verifying code quality
  after implementation, on PR creation (auto-triggered by hook), or manually via
  /qg command. Manages sequential gate execution with loop-back on code changes.
---

# Quality Gates Pipeline

You are orchestrating the 3-gate quality verification pipeline. Execute gates sequentially, handle loop-backs, and track state.

## Arguments

Parse the following from the prompt/arguments:
- `gate1`, `gate2`, `gate3` — run a specific gate only
- `--skip-runtime` — skip Gate 3
- `--plan <path>` — specify plan file path
- `--pr-url <url>` — PR URL (from auto-trigger)
- If no arguments, run the full pipeline (Gate 1 → 2 → 3)

## Configuration

```
MAX_TOTAL_ITERATIONS = 5      # Full pipeline restarts
MAX_GATE2_ITERATIONS = 5      # Review-fix-review cycles within Gate 2
```

## State File

Create/update `.claude/quality-gates.local.md` in the current project directory to track pipeline state.

**Initial state (create at pipeline start):**

```markdown
---
status: gate1
current_gate: 1
total_iterations: 1
gate2_iteration: 0
max_total_iterations: 5
max_gate2_iterations: 5
plan_file: <detected or provided plan path>
pr_url: <PR URL if provided>
started_at: "<current ISO timestamp>"
---

# Quality Gates Pipeline State

## Pipeline History
- [<timestamp>] Pipeline started (iteration 1)
```

Update this file after each gate completes. Use Edit tool to update the YAML frontmatter and append to the history section.

## Dependency Check (Before Pipeline Start)

Before executing the pipeline, verify that required external plugins are available:

```
=== PRE-FLIGHT: Dependency Check ===

1. Check Gate 2 dependency (pr-review-toolkit):
   - Attempt to confirm that pr-review-toolkit agents are available
     (e.g., quality-gates:pr-reviewer dispatches pr-review-toolkit:code-reviewer)
   - If NOT available:
     → Warn user: "⚠ pr-review-toolkit plugin is not installed. Gate 2 (PR Review) will not function correctly.
       Install it with: claude plugin install pr-review-toolkit"
     → Ask: "Continue without Gate 2, or abort?"
     → If continue: mark Gate 2 as SKIP in pipeline

2. Check Gate 3 dependency (browser automation):
   - Check if chrome-devtools-mcp OR playwright MCP tools are available
   - If NEITHER is available:
     → Warn user: "⚠ No browser automation plugin found (chrome-devtools-mcp or playwright).
       Gate 3 (Runtime Verification) will fall back to curl/test-based checks only."
     → This is informational only — Gate 3 has built-in fallback, so proceed automatically

Log dependency check results in the state file history.
```

## Pipeline Execution

### Full Pipeline Flow

```
FOR iteration IN 1..MAX_TOTAL_ITERATIONS:

  === GATE 1: Plan Verification ===

  Dispatch the plan-verifier agent:

  Agent(
    subagent_type="quality-gates:plan-verifier",
    prompt="Verify plan implementation completeness.
      plan_path: <plan_file or 'auto'>
      project_dir: <current working directory>"
  )

  Read the agent's report. Check the Verdict line:
  - PASS → proceed to Gate 2
  - SKIP → proceed to Gate 2 (with warning noted)
  - FAIL →
    Report blocking gaps to the user.
    Ask: "N blocking items remain. Should I implement them, or proceed anyway?"
    - If implement: implement the items, then RESTART this iteration
    - If proceed: mark as passed-with-warnings, continue to Gate 2

  Update state file: status=gate2, append history.

  === GATE 2: Iterative PR Review ===

  FOR gate2_iter IN 1..MAX_GATE2_ITERATIONS:

    Dispatch the pr-reviewer agent:

    Agent(
      subagent_type="quality-gates:pr-reviewer",
      prompt="Run iterative PR review.
        pr_url: <pr_url>
        max_iterations: <MAX_GATE2_ITERATIONS>
        iteration: <gate2_iter>
        project_dir: <current working directory>
        previous_findings: <summary from last iteration or 'none'>"
    )

    Read the agent's report. Check the Verdict line:
    - PASS → proceed to Gate 3
    - NEEDS_RESTART →
      Code was changed. Restart from Gate 1.
      total_iterations++
      BREAK inner loop, CONTINUE outer loop
    - FAIL →
      If gate2_iter < MAX_GATE2_ITERATIONS: continue inner loop
      Else: report remaining issues to user, ask to proceed or abort

  Update state file: status=gate3, append history.

  === GATE 3: Runtime Verification ===

  If --skip-runtime was specified, skip this gate.

  Dispatch the runtime-verifier agent:

  Agent(
    subagent_type="quality-gates:runtime-verifier",
    prompt="Verify application runtime behavior.
      project_dir: <current working directory>
      plan_path: <plan_file>
      project_type: auto
      app_start_command: auto
      app_url: auto"
  )

  Read the agent's report. Check the Verdict line:
  - PASS → ALL GATES PASSED! Break the loop.
  - SKIP → Treat as pass (non-web project). Break the loop.
  - NEEDS_RESTART →
    Code was changed. Restart from Gate 1.
    total_iterations++
    CONTINUE outer loop
  - FAIL →
    Report failures to user.
    Ask: "Runtime verification failed. Should I fix the issues?"
    - If fix: fix issues, restart from Gate 1
    - If skip: mark as passed-with-warnings, break

  === ALL GATES PASSED ===

  Update state file: status=completed
  Delete state file (cleanup). Do NOT delete `.claude/quality-gates-reports/` — it persists for user review.
  Output final summary
  BREAK
```

### If MAX_TOTAL_ITERATIONS Exceeded

```
Report: "Quality pipeline exceeded maximum iterations (5)."
Ask user to choose:
  1. Extend (add 3 more iterations)
  2. Accept as-is (proceed with current state)
  3. Abort (stop pipeline)
```

### Single Gate Execution

If a specific gate was requested (e.g., `/qg gate2`):
- Run only that gate
- Do NOT loop back to other gates
- Report the single gate's result

## Final Summary

When all gates pass (or are accepted), output:

```
## Quality Gates Pipeline — Complete ✓

**Total Iterations:** N
**Duration:** Xm Ys

### Gate Results
| Gate | Status | Details |
|------|--------|---------|
| 1. Plan Verification | PASS | 24/24 items (100%) |
| 2. PR Review | PASS (iter 2) | 2 issues fixed |
| 3. Runtime Verification | PASS | Web app verified |

### Summary of Changes Made
- [file1]: fixed null check (Gate 2)
- [file2]: added error handling (Gate 2)

### Detailed Agent Reports
Individual toolkit agent reports available in `.claude/quality-gates-reports/`:
[list all files in the directory, e.g.:]
- code-reviewer-iter1.md
- silent-failure-hunter-iter1.md
- code-simplifier-iter2.md

PR is ready for merge.
```

## Rules

- ALWAYS create/update the state file — it prevents double-triggering from the hook
- ALWAYS delete the state file when pipeline completes or is aborted — but NEVER delete `.claude/quality-gates-reports/`
- When restarting from Gate 1, increment total_iterations and update state
- Pass context between gates — Gate 2 should know Gate 1's findings, Gate 3 should know the plan
- If ANY gate's agent dispatch fails (error), report the error and ask user how to proceed
- Track ALL code changes across all gates — the final summary should list every file modified
- Update the state file after each gate to track pipeline progress
