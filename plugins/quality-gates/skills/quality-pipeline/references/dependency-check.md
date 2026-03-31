# Dependency Check (Before Pipeline Start)

Before executing the pipeline, verify that required and optional external plugins are available:

```
=== PRE-FLIGHT: Dependency Check ===

1. Check Gate 2 core dependency (pr-review-toolkit) [REQUIRED]:
   - Attempt to confirm that pr-review-toolkit agents are available
   - If NOT available:
     → Warn user: "pr-review-toolkit plugin is not installed. Gate 2 (PR Review) will not function correctly.
       Install it with: claude plugin install pr-review-toolkit"
     → Ask: "Continue without Gate 2, or abort?"
     → If continue: mark Gate 2 as SKIP in pipeline

2. Check Gate 1/2 optional dependency (feature-dev) [OPTIONAL]:
   - Check if feature-dev agents are available
   - If NOT available:
     → Log info: "feature-dev plugin not installed. Convention review (feature-dev:code-reviewer),
       architecture validation (feature-dev:code-architect), and implementation trace
       (feature-dev:code-explorer) will be skipped."
     → Continue automatically (non-blocking)

3. Check Gate 1/2 optional dependency (superpowers) [OPTIONAL]:
   - Check if superpowers agents are available
   - If NOT available:
     → Log info: "superpowers plugin not installed. Plan-aligned review
       (superpowers:code-reviewer) and evidence-based verification
       (superpowers:verification-before-completion) will be skipped."
     → Continue automatically (non-blocking)

4. Check Gate 3 dependency (browser automation) [OPTIONAL]:
   - Check if chrome-devtools-mcp OR playwright MCP tools are available
   - If NEITHER is available:
     → Warn user: "No browser automation plugin found (chrome-devtools-mcp or playwright).
       Gate 3 (Runtime Verification) will fall back to curl/test-based checks only."
     → This is informational only — Gate 3 has built-in fallback, so proceed automatically

Build `available_plugins` list from checks above (e.g., ["pr-review-toolkit", "feature-dev", "superpowers"]).
Log dependency check results in the state file history.
```
