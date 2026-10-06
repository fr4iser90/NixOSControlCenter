# Archive suggest

Read-only plan for archiving quiet git workspaces.

## Rules

- Prefer `ncc ai workflow fleet --json`.
- Never run `gh repo archive` or delete remotes.
- Output: table of candidates + manual GitHub steps + whether to drop from NCC workspaces list.
