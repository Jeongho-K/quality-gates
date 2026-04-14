---
name: quality-pipeline
description: >
  This skill should be used when the user wants to run quality gates, verify code
  quality, check PR readiness, or run the QG pipeline. Triggered by commands like
  "/qg", "run quality gates", "verify my implementation", "check code quality",
  or "is my PR ready to merge". Executes a single gate per turn; the Stop hook
  manages pipeline progression automatically.
---

# Quality Gates — Gate Executor

You are executing a **single gate** of the quality pipeline. The Stop hook manages
pipeline progression (gate-to-gate transitions, iteration counting, loop-back on
code changes). You do NOT manage state files or pipeline flow.

## Preflight

Before parsing arguments or dispatching agents, do this in order:

**1. Detect continuation vs. first invocation.** Look at the current turn's user
prompt. If it contains the literal string `# QG-STOP-HOOK-CONTINUATION` on its
own line, this is a Stop-hook-injected continuation → go to step 2a. Otherwise
it is a first invocation (via `/qg` or direct skill call) →
go to step 2b.

**2a. Continuation path.** The state file MUST exist. Verify:

```bash
test -f .claude/quality-gates.local.md
```

- Exit 0 → proceed to the Arguments section below.
- Non-zero → this is an invariant violation (Stop hook continued a pipeline
  whose state file vanished). Output the following to the user and stop the
  pipeline immediately — do NOT call `setup-qg.sh`, as fresh state would mask
  the real bug:

  > ❌ Pipeline state file disappeared mid-run (`.claude/quality-gates.local.md`).
  > This indicates state corruption or an accidental deletion.
  > Run `/cancel-qg` to clear residual state, then `/qg` to restart.

**2b. First-invocation path.** Bootstrap or validate state by running:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh" --ensure
```

`setup-qg.sh --ensure` handles all cases: creates state if missing, no-ops if
fresh state for this session already exists, overwrites stale state from a
prior (crashed) session, and errors if a concurrent pipeline is genuinely
active.

- Exit 0 → state is valid and session-matched. Proceed to the Arguments section.
- Exit non-zero → surface the script's stderr output to the user verbatim and
  abort. The error is already actionable (e.g. "already active — run
  `/cancel-qg`"); do not attempt recovery.

**Note on the continuation marker.** `# QG-STOP-HOOK-CONTINUATION` is a
deliberate machine-readable sentinel emitted only by
`stop-hook.py:build_gate_prompt()`. If a user types it literally, preflight
will incorrectly take the continuation path — this is an acceptable limitation
for the threat model.

## Arguments

Parse the following from the prompt parameters:

- `gate`: Which gate to execute (1, 2, or 3)
- `plan_path`: Plan file path (or "auto")
- `pr_url`: PR URL (optional)
- `available_plugins`: Comma-separated list of available plugins
- `iteration`: Current Gate 2 iteration number (Gate 2 only)
- `max_iterations`: Maximum Gate 2 iterations (Gate 2 only)
- `previous_findings`: Summary from last Gate 2 iteration (Gate 2 only)

If this is the first gate invocation (no parameters in the prompt), determine the gate
from any `/qg` arguments (gate1, gate2, gate3) or default to gate=1.

## Dependency Check

If `available_plugins` is provided in the prompt parameters, use it directly.

Otherwise (first invocation only), run the pre-flight dependency checks per
[references/dependency-check.md](references/dependency-check.md) to build the
`available_plugins` list.

## Gate Execution

### Gate 1: Plan Verification

Dispatch the plan-verifier agent:

```
Agent(
  subagent_type="quality-gates:plan-verifier",
  prompt="Verify plan implementation completeness.
    plan_path: <plan_path or 'auto'>
    project_dir: <current working directory>
    available_plugins: <available_plugins list>"
)
```

Read the agent's report. Check the Verdict line.

**Implementation Trace (conditional — skill-orchestrated):**

The plan-verifier agent is a leaf agent and does NOT dispatch `feature-dev:code-explorer` itself. Instead, it emits a `### Possibly Implemented (needs trace)` section in its report listing items whose files exist in the git diff but whose checkboxes are unchecked. This skill performs the trace:

1. **Parse the trace section.** Scan the plan-verifier report for a `### Possibly Implemented (needs trace)` header. If the section is absent or empty → no trace is needed. Record "Implementation Trace: Skipped (no possibly-implemented items)" in the Gate 1 output and proceed.
2. **Check plugin availability.** If the section is present but `available_plugins` does NOT include `feature-dev` → skip silently and record "Implementation Trace: Skipped (feature-dev plugin not available)".
3. **Conditional code-explorer dispatch.** If the section is present AND `feature-dev` is available, parse the bulleted items. Each bullet follows the format `- <item text> | files: <comma-separated paths> | line: <N>`. Dispatch `feature-dev:code-explorer` once with the parsed list verbatim:

```
Agent(
  subagent_type="feature-dev:code-explorer",
  prompt="The implementation plan is at <plan_path>. Read it first to understand
    the full scope of planned features.
    Then trace the implementation of the following items that appear to have
    been partially implemented (files exist in git diff but checkboxes unchecked):
    <parsed bullet list verbatim>
    For each, verify it is properly wired up and functional.
    Report which features are fully connected and which have gaps."
)
```

4. **Integrate trace results.** For each item reported as "fully connected", downgrade its status from blocking to "Likely implemented" (non-blocking) in the Gate 1 verdict computation. For each item reported with gaps, keep it as blocking. Append a "Implementation Trace" section to the Gate 1 output summarizing per-item results.
5. **Recompute Gate 1 verdict** using the updated blocking count: if zero blocking items remain → PASS; otherwise FAIL with the remaining count.

**Evidence-Based Verification (conditional):**

If `available_plugins` includes `superpowers` AND the plan-verifier report
contains items in "Likely implemented" or "Possibly implemented" status:

```
Skill("superpowers:verification-before-completion")
```

Follow the skill's gate function:
1. IDENTIFY: Determine which command proves the implementation works
2. RUN: Execute the full command
3. READ: Check full output and exit code
4. VERIFY: Does the output confirm the implementation?

Integrate evidence into Gate 1's verdict.
Note: This step executes commands but does NOT modify any code.

**Output Gate 1 result to user:**
```
## Gate 1: Plan Verification — [PASS/FAIL/SKIP]
[verdict explanation]
[key findings summary]
[evidence-based verification results, if executed]
```

**Handle verdict:**
- PASS → emit signal with verdict="PASS"
- SKIP → emit signal with verdict="SKIP"
- FAIL →
  Report blocking gaps to the user.
  Ask: "N blocking items remain. Should I implement them, or proceed anyway?"
  - If implement: implement the items, then emit signal with verdict="RETRY"
  - If proceed: emit signal with verdict="PASS_WITH_WARNINGS"

### Gate 2: PR Review

Gate 2 is orchestrated inline by this skill — the skill dispatches review
agents directly because Claude Code does not allow agents to dispatch other
agents (only skills can use `Agent()` with `subagent_type`). There is no
intermediate orchestrator agent for Gate 2.

**Tunable constants** (edit this block to tune):

- `AUTO_PLAN_LINE_THRESHOLD = 30` — minimum changed-line count to dispatch `superpowers:code-reviewer` when plan was auto-detected
- `LARGE_DIFF_CHARS = 50000` — if `git diff` stdout exceeds this, fall back to per-agent `git diff` (no inline)
- `LARGE_DIFF_LINES = 800` — same, counted in `+`/`-` lines

**Optimization principles** (preserve QA quality while reducing token cost):

- Capture `git diff` ONCE per iteration and inline it into dispatch prompts so subagents do not re-fetch
- Use deterministic bash checks (not free-form interpretation) to decide Phase 2 dispatches — **fail-open** when checks are ambiguous
- Skip re-running an agent inside the fix-loop only when the fixed files do not intersect its domain
- Structure dispatch prompts as `[immutable head] → [diff] → [variable tail]` for prompt-cache friendliness
- Record every skip decision in the output report — **no silent skips**
- **Never truncate or summarize the diff** — the complete unified diff is passed verbatim

#### Step 0: Resolve plan_path_source and capture diff

First, derive `plan_path_source`:

- If `plan_path` is literally `"auto"` or empty → `plan_path_source = "auto"`
- Otherwise (user passed an explicit path via `/qg --plan=<path>`, or SKILL.md received a concrete resolved path) → `plan_path_source = "explicit"`

This flag decides whether to unconditionally dispatch `superpowers:code-reviewer` (explicit intent, Path A) or gate it on diff characteristics (auto, Path B).

Then run this **single consolidated bash block**. It captures the diff once, writes it to a cache file for later reuse, computes all Phase 2 trigger flags in the same shell where `$DIFF_CONTENT` is still alive, and emits a JSON line to stdout that this skill will parse:

```bash
set -e

DIFF_CONTENT=$(git diff)

mkdir -p .claude
printf '%s' "$DIFF_CONTENT" > .claude/qg-diff-cache.txt

DIFF_CHARS=${#DIFF_CONTENT}
DIFF_LINES=$(printf '%s\n' "$DIFF_CONTENT" | grep -cE '^[+-][^+-]' || echo 0)

LARGE_DIFF_CHARS=50000
LARGE_DIFF_LINES=800
if [ "$DIFF_CHARS" -le "$LARGE_DIFF_CHARS" ] && [ "$DIFF_LINES" -le "$LARGE_DIFF_LINES" ]; then
  INLINE_DIFF_MODE=true
else
  INLINE_DIFF_MODE=false
fi

CHANGED_LINES=$(printf '%s\n' "$DIFF_CONTENT" | grep -E '^[+-][^+-]' || true)

if printf '%s\n' "$CHANGED_LINES" | grep -qE '\b(interface|class|type|struct|enum)\b'; then
  TYPE_DESIGN=1
else
  TYPE_DESIGN=0
fi

if git diff --name-only | grep -qE '(test|spec)\.[jt]sx?$|_test\.py$|\.test\.|\.spec\.|^tests?/'; then
  TEST_CHANGE=1
else
  TEST_CHANGE=0
fi

COMMENT_CHANGE=0
if printf '%s\n' "$CHANGED_LINES" | awk '
  /^\+[[:space:]]*(\/\/|#|\*|\/\*)/ { n++; if (n >= 3) { found=1; exit } }
  !/^\+[[:space:]]*(\/\/|#|\*|\/\*)/ { n=0 }
  END { exit !found }
'; then
  COMMENT_CHANGE=1
fi

NEW_FILES=$(git diff --diff-filter=A --name-only | paste -sd, - 2>/dev/null || true)
CONFIG_TOUCHED=$(git diff --name-only | grep -E '(^|/)(package\.json|tsconfig\.json|pyproject\.toml|Cargo\.toml|go\.mod)$|\.schema\.|/migrations/|\.proto$|openapi\.' | paste -sd, - 2>/dev/null || true)
if [ -n "$NEW_FILES" ] || [ -n "$CONFIG_TOUCHED" ]; then
  ARCH_CHANGE=1
else
  ARCH_CHANGE=0
fi

CHANGED_LINE_COUNT=$(git diff --numstat | awk '{sum += $1 + $2} END {print sum+0}')

printf '{"diff_chars":%d,"diff_lines":%d,"inline_diff_mode":"%s","type_design":%d,"test_change":%d,"comment_change":%d,"new_files":"%s","config_touched":"%s","arch_change":%d,"changed_line_count":%d}\n' \
  "$DIFF_CHARS" "$DIFF_LINES" "$INLINE_DIFF_MODE" "$TYPE_DESIGN" "$TEST_CHANGE" "$COMMENT_CHANGE" "$NEW_FILES" "$CONFIG_TOUCHED" "$ARCH_CHANGE" "$CHANGED_LINE_COUNT"
```

Parse the JSON from the bash stdout and hold the flags in your context. **Fail-open**: if the bash block errors or emits unparseable output, set all Phase 2 flags to `1` so no agent is silently skipped.

If `inline_diff_mode` is `true`, use the `Read` tool on `.claude/qg-diff-cache.txt` to load the diff content into context for reuse in Agent prompts. If `inline_diff_mode` is `false`, skip the Read — subagents will run their own `git diff`.

#### Dispatch Prompt Template

Assemble every Agent prompt in this fixed order so the prefix is cache-friendly:

```
[Section 1 — IMMUTABLE HEAD]
<role-and-rules text; identical across iterations>
<instruction NOT to re-run git diff if INLINE_DIFF_MODE is true>

[Section 2 — DIFF BLOCK]
(only if inline_diff_mode == true)
## Current Diff
```diff
<cached diff content verbatim, unabridged>
```

[Section 3 — VARIABLE TAIL]
iteration: <N>
previous_findings: <previous_findings or 'none'>
changed_files_since_last_dispatch: <list or 'none'>
```

**Never truncate or summarize the diff content when inlining.** The complete unified diff is passed verbatim.

#### Phase 1: Critical Analysis (always run, parallel)

Dispatch these agents **in parallel** (single tool-call block with multiple `Agent()` calls).

**Agent A — pr-review-toolkit:code-reviewer**

Immutable head:
> Review the unstaged changes for bugs, logic errors, security vulnerabilities, and code quality issues. Focus on high-confidence issues only.
>
> If the prompt contains a `## Current Diff` section, operate on that diff verbatim. **Do NOT run `git diff` yourself** — the full unified diff is already provided. You may still use `Read` on specific files for extra context outside the diff's scope.

**Agent B — pr-review-toolkit:silent-failure-hunter**

Immutable head:
> Review the unstaged changes to identify silent failures, inadequate error handling, and inappropriate fallback behavior. Focus on high-confidence issues only.
>
> If the prompt contains a `## Current Diff` section, operate on that diff verbatim. **Do NOT run `git diff` yourself** — the full unified diff is already provided.

**Agent C — feature-dev:code-reviewer** (only if `available_plugins` includes `feature-dev`)

Immutable head:
> Review the unstaged changes for project convention and guideline compliance. Focus on CLAUDE.md adherence, import patterns, naming conventions, and framework-specific patterns. Do NOT focus on bugs or security — another reviewer handles those. Report only issues with confidence >= 80.
>
> If the prompt contains a `## Current Diff` section, operate on that diff verbatim. **Do NOT run `git diff` yourself** — the full unified diff is already provided.

If `feature-dev` is NOT in `available_plugins`, skip Agent C silently and record this in the report's "Phase 2 Skipped Agents" section with reason "feature-dev plugin not available".

Wait for all three agents to complete. Collect their findings.

**Individual dispatch failures**: if any single `Agent()` call fails (plugin missing, agent errors, etc.), record `"<agent-name>: dispatch failed: <error>"` in the output report's "Dispatch Failures" section and continue with the remaining agents. Do not abort Gate 2 on a single failure.

#### Phase 2: Conditional Analysis

Use the flag values parsed from the Step 0 JSON. Every skip must be recorded in the output report — **no silent skips**.

All Phase 2 dispatches are assembled via the template above. Append the following sentence to the end of each Phase 2 agent's immutable head:

> If the prompt contains a `## Current Diff` section, operate on that diff verbatim. **Do NOT run `git diff` yourself** — the full unified diff is already provided.

**If `type_design == 1`** → dispatch `pr-review-toolkit:type-design-analyzer`:
> Analyze all type/interface/class/struct/enum changes in the current diff for encapsulation, invariant expression, and design quality.

**If `test_change == 1`** → dispatch `pr-review-toolkit:pr-test-analyzer`:
> Review the test coverage in the current changes. Identify critical gaps in test coverage for new functionality.

**If `comment_change == 1`** → dispatch `pr-review-toolkit:comment-analyzer`:
> Analyze code comments in the current changes for accuracy, completeness, and long-term maintainability.

**If `arch_change == 1` AND `available_plugins` includes `feature-dev`** → dispatch `feature-dev:code-architect`:
> Analyze the architectural impact of the current diff. Validate that new files follow existing codebase patterns, module boundaries are respected, and architecture remains consistent. Focus on pattern validation, not bugs or style.

##### superpowers:code-reviewer dispatch (Path A / Path B)

**Prerequisites (both must hold):**

- `plan_path` is not empty
- `available_plugins` includes `superpowers`

If prerequisites fail → skip (record reason).

**Path A — Explicit user intent**: if `plan_path_source == "explicit"` → **dispatch unconditionally**.

**Path B — Auto-detected plan**: if `plan_path_source == "auto"` (or absent — treat missing as auto), dispatch only if **any one** of:

1. `new_files` (from Step 0 JSON) is non-empty
2. `changed_line_count >= 30` (`AUTO_PLAN_LINE_THRESHOLD`)
3. `config_touched` (from Step 0 JSON) is non-empty

Otherwise skip and record the reason (e.g., `"skipped: auto mode, 8 changed lines, no new files, no config touch"`).

Dispatch prompt (immutable head):
> Review the unstaged changes against the implementation plan at `{plan_path}`. Check for plan alignment, architectural deviations from planned approach, SOLID principles, and separation of concerns. Categorize issues as Critical, Important, or Suggestions.
>
> If the prompt contains a `## Current Diff` section, operate on that diff verbatim. **Do NOT run `git diff` yourself** — the full unified diff is already provided.

#### Classifying Findings

From each agent's output, classify findings:

- **CRITICAL** (confidence ≥ 90%): Bugs, security vulnerabilities, data loss risks
- **IMPORTANT** (confidence ≥ 80%): Logic errors, poor error handling, missing validation
- **SUGGESTION** (confidence < 80%): Style, naming, simplification opportunities

#### Fix-and-Review Loop

If CRITICAL or IMPORTANT issues are found:

1. **Fix the issues** using `Edit`/`Write` tools (the skill has these directly — no delegation needed).
2. Capture the set of changed files:
   ```bash
   git diff --name-only
   ```
3. **Re-run the Step 0 consolidated bash block** so the cache file and flags reflect the post-fix state. Re-read `.claude/qg-diff-cache.txt` into context.
4. If `iteration < max_iterations`: selectively re-dispatch per the dedup rule below.
5. If `iteration >= max_iterations`: stop and report remaining issues.

##### Agent Domain Mapping (for dedup)

When deciding whether to re-dispatch an agent, compute the intersection of `fix_files` with the agent's domain paths:

| Agent | Domain paths (glob) |
|---|---|
| `pr-review-toolkit:code-reviewer` | `**/*.{ts,tsx,js,jsx,py,go,rs,java,rb,kt,swift,cs,cpp,c,h}` |
| `pr-review-toolkit:silent-failure-hunter` | same as above |
| `feature-dev:code-reviewer` | same as above |
| `pr-review-toolkit:type-design-analyzer` | files containing type/interface/class/struct/enum definitions |
| `pr-review-toolkit:pr-test-analyzer` | test files only (see `test_change` regex) |
| `pr-review-toolkit:comment-analyzer` | files where comment lines were added/changed |
| `superpowers:code-reviewer` | same as code-reviewer (broad) |
| `feature-dev:code-architect` | source files + config/schema files |
| `pr-review-toolkit:code-simplifier` | never re-run (Phase 3 one-shot) |

##### Dedup Decision

For each agent `A` whose last run returned findings:

```
domain_paths_A = expand(A.domain paths)
if fix_files ∩ domain_paths_A == ∅:
  → SKIP re-dispatch. Record "dedup: A's domain untouched by fix"
else:
  → Re-dispatch A with the updated diff content
```

**Fail-open**: if the intersection check is ambiguous (e.g., domain paths hard to enumerate), **re-dispatch anyway**. Broad-domain agents (code-reviewer, silent-failure-hunter, feature-dev:code-reviewer) almost always re-dispatch because their domain covers all source files.

##### Targeted re-dispatch on specific fix types

These rules layer on top of the dedup rule (they can **expand** the re-dispatch set, never shrink it):

- If the fix changes function signatures or module structure → also re-dispatch `feature-dev:code-architect` (if run before)
- If the fix changes error handling → also re-dispatch `silent-failure-hunter`
- If the fix changes types/interfaces → also re-dispatch `type-design-analyzer` (if `type_design` still 1)
- If the fix deviates from plan → also re-dispatch `superpowers:code-reviewer` (if run before)

#### Phase 3: Polish — one-shot rule

Run `pr-review-toolkit:code-simplifier` **only when ALL THREE** conditions hold in the current iteration:

1. Phase 1 produced **zero** CRITICAL or IMPORTANT findings
2. Phase 2 produced **zero** CRITICAL or IMPORTANT findings
3. The fix-loop made **zero** file changes in this iteration

These conditions naturally limit Phase 3 to at most one execution per pipeline run: it runs only in the final clean iteration, after which the pipeline concludes with PASS.

Dispatch prompt (immutable head):
> Review recently modified code for opportunities to simplify for clarity, consistency, and maintainability while preserving all functionality.
>
> If the prompt contains a `## Current Diff` section, operate on that diff verbatim. **Do NOT run `git diff` yourself** — the full unified diff is already provided.

Code-simplifier findings are **always non-blocking** (suggestions only).

#### Detecting Code Changes

After the final fix (or after each iteration), run:

```bash
git diff --name-only
```

Record the list of changed files. This determines the signal verdict (`PASS` if no fixes, `NEEDS_RESTART` if files were modified).

#### Cache Cleanup

Before emitting the Gate 2 signal (on **any** verdict — PASS, FAIL, NEEDS_RESTART, or error), delete the cache file:

```bash
rm -f .claude/qg-diff-cache.txt
```

This must run on every exit path. If the skill turn crashes before cleanup, the next Gate 2 invocation's Step 0 will overwrite the cache — stale content cannot bleed in, but an orphaned cache file is a signal that an earlier run failed abnormally.

#### Output Report

Output a structured report in this exact format. **All skipped agents must be listed with a reason — no silent skips.**

```
## PR Review Report (Gate 2)

**Iteration:** [N]/[max]
**Inline Diff Mode:** [true/false] (diff_chars=[N], diff_lines=[N])
**Agents Dispatched:** [list]
**Files Changed During Fixes:** [list or "none"]

### Phase 2 Skipped Agents
- type-design-analyzer: [reason, e.g. "no type/interface/class/struct/enum in changed lines"]
- pr-test-analyzer: [reason, e.g. "no test files touched"]
- comment-analyzer: [reason, e.g. "no new comment block >= 3 lines added"]
- feature-dev:code-architect: [reason, e.g. "no new files, no config files touched"]
- superpowers:code-reviewer: [reason, e.g. "auto mode, 8 changed lines, no new files, no config touch"]
(omit entries that were dispatched)

### Dedup Skipped (fix-loop re-dispatch)
- [agent-name]: dedup — [agent]'s domain untouched by fix
(or "none")

### Dispatch Failures
- [agent-name]: dispatch failed: [error]
(omit section if none)

### Critical Issues
[list or "none"]

### Important Issues
[list or "none"]

### Suggestions (non-blocking)
[list or "none"]

### Code Changes Made
[list of fixes applied, or "none"]

### Verdict: [PASS / FAIL / NEEDS_RESTART]
[If PASS: "All critical and important issues resolved."]
[If FAIL: "N issues remain after max iterations."]
[If NEEDS_RESTART: "Code was changed during fixes. Pipeline should restart from Gate 1."]
```

**Output Gate 2 result to user:**
```
## Gate 2: PR Review (iter [iteration]) — [PASS/FAIL/NEEDS_RESTART]
[verdict explanation]
[agents run and key findings]
```

**Handle verdict:**
- PASS → emit signal with verdict="PASS"
- NEEDS_RESTART → emit signal with verdict="NEEDS_RESTART"
- FAIL → emit signal with verdict="FAIL"

#### Gate 2 Rules

- NEVER reimplement review logic — always delegate to specialized agents (pr-review-toolkit, feature-dev, superpowers)
- If a plugin is not in `available_plugins`, skip its agents and note the skip in the report
- NEVER truncate, summarize, or filter the cached diff content when inlining — pass the full unified diff verbatim
- NEVER silently skip an agent — every skip must appear in the "Phase 2 Skipped Agents" or "Dedup Skipped" section with a reason
- Fail-open: when any bash check, JSON parse, or intersection test is ambiguous, **dispatch** the agent
- When fixing issues, make minimal changes — don't refactor or improve beyond what's needed
- If an agent returns no findings, that domain is clean — don't re-run it
- `code-simplifier` suggestions NEVER block the pipeline
- Always track which files you modify — the orchestrator needs this for the signal's `files_changed` attribute
- If you changed code, your verdict MUST be `NEEDS_RESTART` (not `PASS`), so Gate 1 can re-verify
- Path A (`plan_path_source == "explicit"`) preserves the original `superpowers:code-reviewer` dispatch behavior — do not gate it on diff size
- Delete `.claude/qg-diff-cache.txt` on every Gate 2 exit path (including errors)

### Gate 3: Runtime Verification

Dispatch the runtime-verifier agent:

```
Agent(
  subagent_type="quality-gates:runtime-verifier",
  prompt="Verify application runtime behavior.
    project_dir: <current working directory>
    plan_path: <plan_path>
    project_type: auto
    app_start_command: auto
    app_url: auto"
)
```

Read the agent's report. Check the Verdict line.

**Output Gate 3 result to user:**
```
## Gate 3: Runtime Verification — [PASS/FAIL/SKIP/NEEDS_RESTART]
[verdict explanation]
[checks performed and results]
```

**Handle verdict:**
- PASS → emit signal with verdict="PASS"
- SKIP → emit signal with verdict="SKIP"
- NEEDS_RESTART → emit signal with verdict="NEEDS_RESTART"
- FAIL → emit signal with verdict="FAIL"

## Special Prompts from Stop Hook

The Stop hook may inject special prompts that start with keywords.
Handle them as follows:

### MAX_TOTAL_ITERATIONS_EXCEEDED

Pipeline exceeded maximum total iterations. Present to user:
1. **Extend** — add 3 more iterations
2. **Accept as-is** — proceed with current state
3. **Abort** — stop pipeline

Based on choice:
- Extend: `<qg-signal action="extend" additional="3" />`
- Accept: `<qg-signal action="complete" />`
- Abort: `<qg-signal action="abort" reason="User chose to abort" />`

### GATE2_MAX_EXCEEDED

Gate 2 exceeded maximum review iterations. Report remaining issues and present:
1. **Proceed to Gate 3** anyway
2. **Abort** pipeline

Based on choice:
- Proceed: `<qg-signal gate="2" verdict="PASS_WITH_WARNINGS" summary="Proceeding with remaining issues" files_changed="" />`
- Abort: `<qg-signal action="abort" reason="User chose to abort" />`

### GATE3_FAIL

Gate 3 failed. Present:
1. **Fix issues** (will restart from Gate 1)
2. **Skip** runtime verification
3. **Abort** pipeline

Based on choice:
- Fix: fix the issues, then `<qg-signal gate="3" verdict="NEEDS_RESTART" summary="Fixed runtime issues" files_changed="list,of,changed,files" />`
- Skip: `<qg-signal gate="3" verdict="SKIP" summary="User chose to skip" files_changed="" />`
- Abort: `<qg-signal action="abort" reason="User chose to abort" />`

## Final Summary

When the Stop hook signals this is the last gate (no more gates after this),
output the final pipeline summary:

```
## Quality Gates Pipeline — Complete

### Gate Results
| Gate | Status | Details |
|------|--------|---------|
| 1. Plan Verification | [status] | [details] |
| 2. PR Review | [status] | [details] |
| 3. Runtime Verification | [status] | [details] |

### Summary of Changes Made
- [file]: [what was changed] (Gate N)

PR is ready for merge.
```

## Signal Tag Rules

After each gate completes, you **MUST** output a signal tag. This is how the Stop
hook knows what happened and what to do next.

**Gate completion signals:**
```xml
<qg-signal gate="N" verdict="VERDICT" summary="one-line summary" files_changed="comma,separated,list" />
```

Verdict values:
- `PASS` — Gate succeeded, no issues
- `FAIL` — Gate failed, issues remain
- `SKIP` — Gate skipped (no plan file, non-web project, etc.)
- `NEEDS_RESTART` — Code was changed, pipeline should restart from Gate 1
- `PASS_WITH_WARNINGS` — Gate passed with non-blocking warnings
- `RETRY` — Gate needs to re-run (Gate 1 implemented missing items)

For Gate 2, include the `iteration` attribute:
```xml
<qg-signal gate="2" verdict="PASS" iteration="3" summary="All issues resolved" files_changed="" />
```

**Pipeline control signals:**
```xml
<qg-signal action="complete" />
<qg-signal action="abort" reason="description" />
<qg-signal action="extend" additional="3" />
```

## Rules

- NEVER directly read or write the contents of `.claude/quality-gates.local.md`. All state creation, validation, and stale-state cleanup is delegated to `setup-qg.sh`; mutation is the Stop hook's job. The skill may probe existence with `test -f` (Preflight only) and invoke `setup-qg.sh --ensure` via Bash. No other interaction is permitted.
- ALWAYS emit exactly one `<qg-signal>` tag at the end of your response
- Output each gate's result to the user immediately
- If an agent dispatch fails (error), report the error and emit signal with verdict="FAIL"
- The `files_changed` attribute must list every file modified during this gate (comma-separated), or empty string if none
- The `summary` attribute should be a concise one-line description of the gate result
