# PR Process

## PR Body Template

```markdown
## Summary
- [1-3 bullet points describing the changes]

## Test Plan
- [ ] [Verification steps]
- [ ] [Edge cases tested]
```

## Creating a PR

1. Ensure your branch is up to date with the base branch
2. Push with upstream tracking: `git push -u origin <branch-name>`
3. Create the PR:

```bash
gh pr create --title "<type>: <description>" --body "$(cat <<'EOF'
## Summary
- <what changed and why>

## Test Plan
- [ ] <verification steps>

Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

## PR Title

- Under 70 characters
- Use Conventional Commits prefix: `feat:`, `fix:`, `refactor:`, etc.
- Imperative mood: "add", not "added"

## Merge Strategy

Default: **{{MERGE_STRATEGY}}**

| Strategy | When to use |
|----------|------------|
| **Squash merge** | Branch has WIP/messy commits, want clean single commit on base |
| **Merge commit** | All commits are clean and meaningful, want to preserve full history |
| **Rebase** | Want linear history, all commits are well-formed |

## Review Checklist

Before requesting review:

- [ ] All tests pass locally
- [ ] No unintended file changes (`git diff --stat`)
- [ ] Branch is up to date with base branch
- [ ] Commit messages follow conventions (`docs/git-workflow/commit-conventions.md`)
- [ ] PR description accurately reflects changes

## Plugin Integration

- **commit-commands**: Use `/commit-push-pr` for streamlined PR creation
- **quality-gates** (if installed): Auto-triggers quality pipeline on `gh pr create`
