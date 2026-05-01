# Retrofit Status — Existing Plugins vs. Harness Philosophy

Light-pass audit performed when the harness philosophy landed (`feature/harness-philosophy`). This is a snapshot, not a deep review — it produces a 3-bullet status per plugin to feed future retrofit planning rounds. The philosophy itself (out-of-scope items in [`devbrew-harness-philosophy.md`](devbrew-harness-philosophy.md) §9 Q10) defers full retrofit to a later round.

**What this file is:** a compounding artifact (Law 3) — a durable record of which laws, principles, and anti-patterns each existing plugin satisfies vs. has gaps on. Future sessions can grep this file for a plugin name or a principle ID and know where the current state stands without re-auditing.

**What this file is NOT:** an action list, a migration plan, or a commitment to retrofit on any schedule. Retrofits happen when the affected plugin bumps its version for unrelated reasons and a principle adoption can ride along without thrashing.

---

## plugins/quality-gates (v1.4.0)

**Already satisfies:**
- **Laws 1 & 2 via gate architecture.** Gate 1 (plan-verifier agent) checks spec completeness against implementation; Gate 2 (quality-pipeline skill) dispatches pr-review-toolkit, feature-dev, and superpowers review agents in phases — writer/reviewer separation is structural via delegation; Gate 3 (runtime-verifier) runs the app and captures console errors. This is the reference implementation of P4 (Verification Is Infrastructure) and P3 (Writer/Reviewer Isolation).
- **P9 Composition over Monolith.** Gate 2 does not ship its own reviewers — it dispatches `pr-review-toolkit:code-reviewer`, `pr-review-toolkit:silent-failure-hunter`, `feature-dev:code-reviewer`, etc. The philosophy's "citizen of a marketplace" model is already the plugin's operating stance.
- **P14 State Survives Compaction + P15 Initializer/Resumer.** Stop-hook state machine (`stop-hook.py`) reads `<qg-signal>` tags, computes next state, and injects the next gate's prompt. State lives in `.claude/quality-gates.local.md` (already matches §4.8 convention). The setup script initializes; subsequent turns resume.
- **Declared dependencies.** README prerequisites table lists `pr-review-toolkit` (required), `feature-dev`, `superpowers`, `chrome-devtools-mcp`/`playwright` with purpose. Matches AP12 (undeclared dependencies forbidden).

**Gaps against the philosophy:**
- **P21 Security & Supply Chain — no `integrity` pinning.** Declared dependencies do not currently pin git SHA or tag for the plugins whose agents are dispatched. This is an enhancement, not a live vulnerability — but when P21 becomes enforced, quality-gates is the primary plugin that will need `integrity` fields added to its declared dependencies.
- **P22 Cost Awareness — no `cost_class` on the quality-pipeline skill.** Gate 2 dispatches multiple agents in parallel phases; worst-case cost is clearly `medium` or `high` depending on how many phases run. The skill should declare this and potentially gate Gate 2 entry on cost acknowledgment.
- **P23 Versioning & CHANGELOG.** Plugin is at v1.4.0 — above the v1.0.0 threshold — but has no `CHANGELOG.md` at the plugin root. The bump history lives in commit messages (which is partial compliance). Retrofit candidate: add `CHANGELOG.md` with entries backfilled from `git log`.
- **P10 Taste Pluralism / persona library** — quality-gates delegates to pr-review-toolkit's persona set rather than owning one. This is consistent with P9 (composition) and not a gap per se, but when the persona library question (§9 Q3) is resolved, quality-gates' delegation contract may need updating.
- **`cost_class` on Gate 3 runtime-verifier** — runtime checks (browser automation) can be expensive on large apps. Worth declaring `variable` with a note about input-size dependency.

**Retrofit candidates (in order, for when the plugin next bumps):**
1. Add `CHANGELOG.md` backfilled from git log (P23). Patch bump.
2. Add `cost_class` declarations to quality-pipeline skill and runtime-verifier agent (P22). Minor bump (additive).
3. Add `integrity` pinning for declared dependencies once the ecosystem supports it (P21). Minor bump if additive, major if it changes the dispatch contract.
4. Consider whether Gate 2 should add a terminal `compound` step (Law 3, §4.6) — captures learnings from each gate cycle to a compounding destination once §9 Q5 is resolved. This is the largest retrofit and should wait for Round N+4 (compounding step design) before executing.

---

## plugins/project-init (v1.1.0)

**Already satisfies:**
- **P13 Hooks for Enforcement (validation subclass).** PostToolUse hook validates branch naming and commit message format — this is exactly the "validation, not behavior injection" stance P13 endorses. The hook reads CLAUDE.md rules rather than hardcoding them, so the enforcement is declarative and portable across strategies.
- **P20 Commit Trailers readiness.** Plugin ships `templates/shared/commit-conventions.md` which is the natural home for documenting the structured commit trailer protocol (`Constraint:`, `Rejected:`, `Directive:`, `Confidence:`, etc.) when P20 gets wider adoption.
- **Composition-friendly integration.** README integration section explicitly describes interop with commit-commands, superpowers, and quality-gates — matches P9 stance.

**Gaps against the philosophy:**
- **Directory layout drift from §4.0.** Plugin has no `scripts/` directory (hooks/post-tool-use.py lives under `hooks/`, which is fine per §4.0), but no `agents/`, `skills/`, or `reviewers/` subdirectories — which is correct because the plugin doesn't need them. The gap is that the README does not list "Principles Instantiated," which §4.0 now requires. This is a docs retrofit.
- **P23 Versioning & CHANGELOG.** Plugin is at v1.1.0 — above the v1.0.0 threshold — but has no `CHANGELOG.md`. Same fix as quality-gates.
- **P21 Security — the PostToolUse hook reads CLAUDE.md at runtime.** If CLAUDE.md is malicious (prompt injection), the hook could mis-validate. Low risk in practice because the hook is a grep-and-match script rather than an LLM call, but worth documenting in the README's security posture.
- **Git Flow and Trunk-based templates still shipped alongside GitHub Flow.** devbrew has committed to GitHub Flow as the repo's own workflow (see `docs/git-workflow/` and recent commits `37a084f docs(git-workflow): replace Git Flow with GitHub Flow`). The plugin still ships all three templates, which is correct for a *generic* git-workflow plugin but may need a note in the README clarifying that devbrew itself uses GitHub Flow and Git Flow / Trunk-based templates are for consumers of the plugin, not devbrew's own use.

**Retrofit candidates (in order, for when the plugin next bumps):**
1. Add `CHANGELOG.md` backfilled from git log (P23). Patch bump.
2. Add "Principles Instantiated" section to README listing P13, P20, P9, P12 (transparency via interactive setup), and the AP5 "trivia escape" affordance the hook provides (P23, §4.0). Patch bump (docs).
3. Document the commit trailer protocol (P20) in `templates/shared/commit-conventions.md` as an optional section for plugins that want decision audit trails. Minor bump (new template content).

---

## Summary

Both existing plugins are **substantially compatible** with the harness philosophy — quality-gates is in fact the reference implementation of Laws 1, 2, and 4 primitives. Neither plugin has breaking gaps. All gaps fall into two categories:

1. **Docs debt** — CHANGELOG.md missing, "Principles Instantiated" README sections missing. Cheap patch bumps.
2. **New principles introduced in the philosophy (P21, P22, P23)** that didn't exist when the plugins were written. These require additive changes and should ride along with the next unrelated version bump rather than triggering a dedicated retrofit PR.

**No urgent retrofit action required.** The philosophy can land without retrofit and the plugins continue to work. The next natural bump for quality-gates (whenever it happens) is a good moment to add the CHANGELOG and `cost_class` declarations. project-init's next bump (whenever a new template or validation rule is added) is the moment to add its CHANGELOG and "Principles Instantiated" section.

This audit file is updated whenever either plugin bumps or when a new principle materially affects either plugin's status.
