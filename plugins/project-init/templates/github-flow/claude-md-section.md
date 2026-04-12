## Git Workflow

GitHub Flow. Branch from `main`, merge back via PR. Details in `docs/git-workflow/`.

- Branch: `feature/*` or `fix/*` from `main`. Kebab-case, 2-4 words.
- Commit: Conventional Commits (`<type>(<scope>): <description>`)
- PR: {{MERGE_STRATEGY}}, see `docs/git-workflow/pr-process.md`
- project-init plugin auto-validates branch naming and commit format
