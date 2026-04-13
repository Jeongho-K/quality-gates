# Branch Strategy: GitHub Flow

## Model

- `main` is the production branch — always deployable
- All work happens on short-lived `feature/*` or `fix/*` branches
- No `develop`, `release`, or `staging` branches

## Branch Naming Pattern

```regex
^(feature|fix)/[\w.-]+$
```

## Branch Prefixes

| Prefix | Use | Example |
|--------|-----|---------|
| `feature/<name>` | New feature or enhancement | `feature/user-auth` |
| `fix/<name>` | Bug fix | `fix/login-redirect` |

- Use **kebab-case** for the description
- Keep it concise: 2-4 words
- Max 50 characters total

## Branch Lifecycle

### Creating a branch

Always start from latest `main`:

```bash
git checkout main
git pull origin main
git checkout -b feature/<name>
```

### Continuing work on an existing branch

Sync with main before continuing. This project prefers **merge** over rebase when syncing an existing feature branch (rebase is disallowed for already-shared branches):

```bash
git checkout feature/<name>
git fetch origin
git merge origin/main
```

### After PR merge

- Delete the branch (usually handled by `gh pr merge --delete-branch`)
- Or keep and sync from main for follow-up work

## Rules for Claude

- **ALWAYS** check current branch before starting work: `git branch --show-current`
- **NEVER** commit directly to `main`
- **ALWAYS** use `feature/*` or `fix/*` branch naming
- When asked to "start working on X" — create a properly named branch first
- If on `main` and about to make changes — STOP and create a branch first
- When syncing an existing feature branch with `main` — use `git merge`, not `git rebase`
