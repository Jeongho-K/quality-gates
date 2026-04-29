# Model Override Experiment Result

**Date:** 2026-04-29
**Branch:** feature/qg-cost-reduction
**Plan reference:** `~/.claude/plans/qg-melodic-fiddle.md` §B "사전 검증"; `~/.claude/plans/2026-04-29-qg-cost-reduction-impl.md` Task 1.

## Test

Dispatched `pr-review-toolkit:silent-failure-hunter` (frontmatter `model: inherit`) twice via the Task tool from a session whose parent harness model is Opus 4.7:

1. **With explicit `model: "sonnet"` override** — agent prompted to self-identify its model.
2. **Without `model` parameter** — same self-identification prompt.

The agent's identity claim is the proxy signal: the model that handles the dispatch reads its own system prompt and reports back.

## Result

| Run | `model` parameter | Self-reported model |
|---|---|---|
| 1 | `"sonnet"` | **Sonnet 4.6** ("my system prompt identifies me as claude-sonnet-4-6") |
| 2 | (omitted) | **Opus 4.7** ("my system prompt states I am powered by the model named Opus 4.7 (1M context)") |

Override worked: **YES**.

## Implication for SKILL.md dispatch

For cross-plugin agents with `model: inherit` frontmatter — i.e. all of `pr-review-toolkit:silent-failure-hunter`, `type-design-analyzer`, `pr-test-analyzer`, `comment-analyzer`, and `superpowers:code-reviewer` — Task tool `model: "sonnet"` cleanly overrides to Sonnet. The Phase 1 dispatch table in the design plan (§B) can be implemented as written.

For cross-plugin agents with hardcoded `model: opus` (i.e. `pr-review-toolkit:code-reviewer`, `pr-review-toolkit:code-simplifier`) we do **not** override per user direction — upstream's hardcoded model is respected.

For cross-plugin agents with hardcoded `model: sonnet` (i.e. `feature-dev:code-architect`, `feature-dev:code-explorer`, `feature-dev:code-reviewer`) we likewise do not override.

## Caveat

The self-identification check is heuristic — models can in principle hallucinate identity. This result is consistent with two independent runs in opposite directions and matches Anthropic's documented Task-tool override semantics, so we treat it as a reliable confirmation. If a future Claude Code version changes override semantics, re-run this probe.
