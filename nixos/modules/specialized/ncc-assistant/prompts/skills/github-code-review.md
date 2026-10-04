# GitHub Code Review

Review pull requests that carry the trigger label and/or request the configured reviewer.

## Behaviour

- Poll each repository independently; never collide PR numbers across repos.
- Record exact-head decisions; stop early on out-of-scope changes.
- Match review tone (brief / detailed / nitpicky).
- After exact-head approval, optionally request a maintainer from the maintainers list based on changed-path history and load.
- Use the GitHub token secret from the agent profile — never echo the token.

## Stop conditions

- Out-of-scope diff → stop with summary.
- Maintainer-decision scope stop when configured.
- Budget / step limit exhausted.
