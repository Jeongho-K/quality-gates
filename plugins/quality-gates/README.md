# Quality Gates Plugin

3-gate quality verification pipeline for Claude Code with multi-plugin review delegation.

## Architecture

```
quality-gates/
├── .claude-plugin/         # Plugin metadata
│   └── plugin.json
├── agents/                 # Gate agents (dispatched by pipeline)
│   ├── plan-verifier.md    # Gate 1
│   ├── pr-reviewer.md      # Gate 2
│   └── runtime-verifier.md # Gate 3
├── commands/
│   └── qg.md               # /qg slash command
├── hooks/
│   ├── hooks.json           # Hook configuration
│   └── post-tool-use.py     # Auto-trigger on PR creation
└── skills/
    └── quality-pipeline/
        ├── SKILL.md         # Pipeline orchestrator
        └── references/
            ├── dependency-check.md   # Pre-flight dependency checks
            └── state-file-format.md  # Pipeline state file format
```

## Gates

| Gate | Agent | Purpose | Delegates To |
|------|-------|---------|-------------|
| 1 | plan-verifier | Cross-references plan checkboxes with git diff | feature-dev:code-explorer (impl trace), superpowers:verification-before-completion (evidence, via pipeline) |
| 2 | pr-reviewer | Orchestrates multi-plugin review agents iteratively | pr-review-toolkit (core review), feature-dev (conventions, architecture), superpowers (plan alignment) |
| 3 | runtime-verifier | Starts the app, checks console errors, takes screenshots | chrome-devtools-mcp or playwright |

## Gate 2 Review Phases

```
Phase 1 (Critical, always run, parallel):
  ├── pr-review-toolkit:code-reviewer        → bugs, security, logic
  ├── pr-review-toolkit:silent-failure-hunter → error handling
  └── feature-dev:code-reviewer              → conventions, guidelines

Phase 2 (Conditional):
  ├── pr-review-toolkit:type-design-analyzer  → new types
  ├── pr-review-toolkit:pr-test-analyzer      → test changes
  ├── pr-review-toolkit:comment-analyzer      → documentation
  ├── superpowers:code-reviewer               → plan alignment
  └── feature-dev:code-architect              → architecture

Phase 3 (Polish, non-blocking):
  └── pr-review-toolkit:code-simplifier       → simplification
```

## Pipeline Flow

The pipeline runs gates sequentially. If code changes are made during review, it **loops back** to Gate 1 to re-verify — ensuring fixes don't break earlier checks. Each gate's result is output to the user immediately upon completion.

```mermaid
flowchart TD
    Start(["/qg or gh pr create"]) --> DepCheck{"Dependency\nCheck"}
    DepCheck -->|OK| G1
    DepCheck -->|Missing| Warn["Warn & ask\nto continue"]
    Warn --> G1

    subgraph Pipeline ["Pipeline Loop (max 5 iterations)"]
        G1["Gate 1\nPlan Verification"]
        G1 -->|PASS| G2
        G1 -->|FAIL| Fix1["Implement\nmissing items"]
        Fix1 --> G1

        G2["Gate 2\nPR Review"]
        G2 -->|PASS| G3
        G2 -->|Code changed| Restart["Restart\nfrom Gate 1"]
        Restart --> G1

        subgraph G2Loop ["Review-Fix Loop (max 5 iterations)"]
            G2
        end

        G3["Gate 3\nRuntime Verification"]
        G3 -->|Code changed| Restart
    end

    G3 -->|PASS| Done(["All Gates Passed\nPR ready for merge"])
    G3 -->|SKIP| Done
```

## Auto-trigger Flow

When a PR is created via `gh pr create`, the hook automatically triggers the pipeline:

```mermaid
sequenceDiagram
    participant User
    participant Claude as Claude Code
    participant Hook as post-tool-use.py
    participant QG as Quality Pipeline

    User->>Claude: gh pr create
    Claude->>Claude: Bash tool executes
    Claude->>Hook: PostToolUse event
    Hook->>Hook: Detect "gh pr create"
    Hook->>Hook: Check state file (prevent double-trigger)
    Hook->>Hook: Extract PR URL from output
    Hook-->>Claude: systemMessage: "Run quality pipeline"
    Claude->>QG: Invoke quality-pipeline skill
    QG->>QG: Gate 1 → 2 → 3
    QG-->>Claude: Final report
    Claude-->>User: Quality Gates Complete
```

## Installation

### 1. Clone the plugin

```bash
git clone https://github.com/Jeongho-K/quality-gates ~/.claude/plugins/quality-gates
```

### 2. Register with Claude Code

```bash
claude plugin add ~/.claude/plugins/quality-gates
```

If `claude plugin add` is not available, manually add to `~/.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "quality-gates@local-qg": true
  },
  "extraKnownMarketplaces": {
    "local-qg": {
      "source": {
        "source": "directory",
        "path": "~/.claude/plugins/quality-gates"
      }
    }
  }
}
```

> Replace `~` with your actual home directory path (e.g., `/home/username`).

### 3. Install required plugins

**pr-review-toolkit** (required for Gate 2 — core review):

```bash
claude plugin add pr-review-toolkit
```

### 4. Install optional plugins

These plugins enhance the pipeline with additional review perspectives:

**feature-dev** (optional — convention review, architecture validation, implementation trace):
```bash
claude plugin add feature-dev
```

**superpowers** (optional — plan-aligned review, evidence-based verification):
```bash
claude plugin add superpowers
```

**Browser automation** (optional for Gate 3 — runtime verification), install one of:

```bash
# Option A: Chrome DevTools MCP
claude plugin add chrome-devtools-mcp

# Option B: Playwright
claude plugin add playwright
```

## Prerequisites

| Plugin | Required | Used By | Purpose |
|--------|----------|---------|---------|
| pr-review-toolkit | Yes | Gate 2 | Core review agents |
| feature-dev | No | Gate 1, 2 | Convention review, architecture, impl trace |
| superpowers | No | Gate 1, 2 | Plan alignment, evidence verification |
| chrome-devtools-mcp / playwright | No | Gate 3 | Browser automation |

## Usage

**Manual:** `/qg` or `/qg gate2` or `/qg --skip-runtime`

**Auto-trigger:** Creates PR with `gh pr create` -> hook injects pipeline automatically.

## Configuration

- `MAX_TOTAL_ITERATIONS`: 5 (full pipeline restarts)
- `MAX_GATE2_ITERATIONS`: 5 (review-fix cycles within Gate 2)

## State File

Pipeline state is tracked in `.claude/quality-gates.local.md` (auto-created, auto-deleted).
