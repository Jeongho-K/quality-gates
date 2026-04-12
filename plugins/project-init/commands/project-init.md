---
description: "Initialize git workflow rules for the project (branch strategy, commit conventions, PR process)"
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---

# project-init

Initialize git workflow rules by selecting a branching strategy template, then generating CLAUDE.md and docs/ files for the project.

## Instructions

Follow these steps exactly in order.

### Step 1: Detect project state

1. Check if `CLAUDE.md` exists in the project root
2. If it exists, check if a `## Git Workflow` section already exists
3. Check if `docs/git-workflow/` directory exists

If existing Git Workflow configuration is found, ask the user:
> "Existing git workflow rules detected. Replace them with the new template?"

If the user declines, stop.

### Step 2: Select branching strategy

Present these 3 options to the user:

| Strategy | Branches | Best for |
|----------|----------|----------|
| **GitHub Flow** | `main` + `feature/*` / `fix/*` | Small teams, CI/CD, continuous deployment |
| **Git Flow** | `main` + `develop` + `feature/*` / `fix/*` / `release/*` / `hotfix/*` | Teams with release cycles, version management |
| **Trunk-based** | `main` + short-lived `feature/*` / `fix/*` | Fast deployment, feature flag teams |

Wait for the user to choose.

### Step 3: Customization questions

Ask these questions based on the selected strategy:

**For all strategies:**

1. **Commit scope convention** — "How should commit scopes be defined?"
   - By module/directory name (e.g., `feat(auth):`, `fix(api):`)
   - By feature area (e.g., `feat(login):`, `fix(checkout):`)
   - No scope required (e.g., `feat:`, `fix:`)

2. **Default merge strategy** — "What's the default PR merge strategy?"
   - Squash merge (recommended for clean history)
   - Merge commit (preserves all commits)
   - Rebase (linear history)

**Additional for Git Flow:**

3. **Release branch naming** — "Release branch format?"
   - `release/v*` (e.g., `release/v1.2.0`) — default
   - Custom format

### Step 4: Generate files

Based on the selected strategy and answers, generate the following files.

**Important:** The template files are located at `${CLAUDE_PLUGIN_ROOT}/templates/`. Read them, replace placeholders, and write to the project.

#### 4a: Read templates

Read these files from the plugin:
- `${CLAUDE_PLUGIN_ROOT}/templates/<strategy>/claude-md-section.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/<strategy>/branch-strategy.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/shared/commit-conventions.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/shared/pr-process.md`

Where `<strategy>` is one of: `github-flow`, `git-flow`, `trunk-based`.

#### 4b: Replace placeholders

Replace these placeholders in the template content:

| Placeholder | Replace with |
|-------------|-------------|
| `{{SCOPE_CONVENTION}}` | The scope rule from Step 3 question 1 (e.g., "Scope by module/directory name: `auth`, `api`, `ui`") |
| `{{MERGE_STRATEGY}}` | The merge strategy from Step 3 question 2 (e.g., "squash merge") |

#### 4c: Write CLAUDE.md section

- If `CLAUDE.md` exists and has a `## Git Workflow` section: **replace** that section only (preserve all other content)
- If `CLAUDE.md` exists but has no `## Git Workflow` section: **append** the section at the end
- If `CLAUDE.md` does not exist: **create** the file with the section

Use the content from `claude-md-section.md` (with placeholders replaced).

#### 4d: Write docs/git-workflow/ files

Create the directory `docs/git-workflow/` if it doesn't exist. Write these 3 files:

1. `docs/git-workflow/branch-strategy.md` — from `templates/<strategy>/branch-strategy.md`
2. `docs/git-workflow/commit-conventions.md` — from `templates/shared/commit-conventions.md` (with placeholders replaced)
3. `docs/git-workflow/pr-process.md` — from `templates/shared/pr-process.md` (with placeholders replaced)

### Step 5: Confirm

Report what was created:

> Git workflow initialized with **{strategy name}** strategy.
>
> Files created/updated:
> - `CLAUDE.md` — Git Workflow section added
> - `docs/git-workflow/branch-strategy.md` — Branch rules
> - `docs/git-workflow/commit-conventions.md` — Commit conventions
> - `docs/git-workflow/pr-process.md` — PR process
>
> The `project-init` plugin hook will auto-validate branch names and commit messages.
> Use `/commit` or `/commit-push-pr` (commit-commands plugin) for streamlined git operations.
