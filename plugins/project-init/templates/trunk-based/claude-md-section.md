## Git Workflow

Trunk-based development. All work merges to `main` quickly. Details in `docs/git-workflow/`.

- Branch: Short-lived `feature/*` or `fix/*` from `main`. Merge within 1-2 days.
- Commit: Conventional Commits (`<type>(<scope>): <description>`)
- PR: {{MERGE_STRATEGY}}, see `docs/git-workflow/pr-process.md`
- Use feature flags for incomplete features. Keep `main` always deployable.
- project-init plugin auto-validates branch naming and commit format
