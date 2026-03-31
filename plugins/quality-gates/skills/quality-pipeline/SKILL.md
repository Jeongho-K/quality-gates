---
name: quality-pipeline
description: >
  This skill should be used when the user wants to run quality gates, verify code
  quality, check PR readiness, or run the QG pipeline. Triggered by commands like
  "/qg", "run quality gates", "verify my implementation", "check code quality",
  "is my PR ready to merge", or automatically on PR creation via hook. Executes a
  3-gate sequential pipeline: plan verification, PR review, and runtime verification,
  with automatic loop-back when code changes occur.
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

Create/update `.claude/quality-gates.local.md` per the format in [references/state-file-format.md](references/state-file-format.md). Update this file after each gate completes.

## Dependency Check (Before Pipeline Start)

Run the pre-flight dependency checks per [references/dependency-check.md](references/dependency-check.md) before starting the pipeline. This builds the `available_plugins` list used by all gates.

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
      project_dir: <current working directory>
      available_plugins: <available_plugins list from dependency check>"
  )

  Read the agent's report. Check the Verdict line.

  === GATE 1.5: Evidence-Based Verification (conditional) ===

  If `available_plugins` includes `superpowers` AND the plan-verifier report
  contains items in "Likely implemented" or "Possibly implemented" status:

  Skill("superpowers:verification-before-completion")

  Follow the skill's gate function:
  1. IDENTIFY: Determine which command proves the implementation works (test suite, build, lint, etc.)
  2. RUN: Execute the full command
  3. READ: Check full output and exit code
  4. VERIFY: Does the output confirm the implementation?

  Integrate evidence into Gate 1's verdict — items with passing evidence
  are more confidently "implemented".

  If `superpowers` is NOT in `available_plugins`, skip this step.

  Note: This step executes commands (tests, builds) but does NOT modify any code.

  **Output Gate 1 result to user immediately:**
  ```
  ## Gate 1: Plan Verification — [PASS/FAIL/SKIP]
  [verdict explanation]
  [key findings summary]
  [evidence-based verification results, if executed]
  ```

  Handle verdict:
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
        previous_findings: <summary from last iteration or 'none'>
        available_plugins: <available_plugins list from dependency check>
        plan_path: <plan_file or empty>"
    )

    Read the agent's report. Check the Verdict line.

    **Output Gate 2 result to user immediately:**
    ```
    ## Gate 2: PR Review (iter [gate2_iter]) — [PASS/FAIL/NEEDS_RESTART]
    [verdict explanation]
    [agents run and key findings]
    ```

    Handle verdict:
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

  Read the agent's report. Check the Verdict line.

  **Output Gate 3 result to user immediately:**
  ```
  ## Gate 3: Runtime Verification — [PASS/FAIL/SKIP/NEEDS_RESTART]
  [verdict explanation]
  [checks performed and results]
  ```

  Handle verdict:
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
  Delete state file (cleanup).
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

PR is ready for merge.
```

## Rules

- ALWAYS create/update the state file — it prevents double-triggering from the hook
- ALWAYS delete the state file when pipeline completes or is aborted
- When restarting from Gate 1, increment total_iterations and update state
- Output each gate's result to the user immediately after completion — do not wait until the end
- Pass context between gates — Gate 2 should know Gate 1's findings, Gate 3 should know the plan
- If ANY gate's agent dispatch fails (error), report the error and ask user how to proceed
- Track ALL code changes across all gates — the final summary should list every file modified
- Update the state file after each gate to track pipeline progress
