## Git Workflow

Git Flow. `main` for releases, `develop` for integration. Details in `docs/git-workflow/`.

- Branch: `feature/*` from `develop`, `hotfix/*` from `main`. Kebab-case, 2-4 words.
- Commit: Conventional Commits (`<type>(<scope>): <description>`)
- PR: {{MERGE_STRATEGY}}, see `docs/git-workflow/pr-process.md`
- Feature branches merge to `develop`, releases and hotfixes merge to both `main` and `develop`
- project-init plugin auto-validates branch naming and commit format
