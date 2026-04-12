# Branch Strategy: Trunk-Based Development

## Model

- `main` (trunk) — always deployable, the single source of truth
- Short-lived `feature/*` or `fix/*` branches — merge within 1-2 days
- No long-lived branches (`develop`, `release`, `staging`)
- Use **feature flags** to hide incomplete features in production

## Branch Naming Pattern

```regex
^(feature|fix)/[\w.-]+$
```

## Branch Prefixes

| Prefix | Use | Example |
|--------|-----|---------|
| `feature/<name>` | New feature (behind flag if incomplete) | `feature/user-auth` |
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

### Working on the branch

- Keep branches short-lived: 1-2 days maximum
- Make small, frequent commits
- If a feature takes longer, use a feature flag and merge intermediate work

### Merging back

- Create a PR to `main`
- Merge as soon as review passes
- Delete the branch immediately after merge

```bash
# After PR merge
git checkout main
git pull origin main
git branch -d feature/<name>
```

## Feature Flags

For features that span multiple days:
- Wrap new code behind a feature flag
- Merge to `main` with the flag disabled
- Enable the flag when the feature is complete and tested

## Rules for Claude

- **ALWAYS** check current branch before starting work: `git branch --show-current`
- **NEVER** commit directly to `main`
- **ALWAYS** use `feature/*` or `fix/*` branch naming
- **ALWAYS** keep branches short-lived — merge within 1-2 days
- When asked to "start working on X" — create a branch from latest `main`
- If a feature is large — suggest using a feature flag and merging in parts
- If on `main` and about to make changes — STOP and create a branch first
- After PR merge — delete the branch immediately
