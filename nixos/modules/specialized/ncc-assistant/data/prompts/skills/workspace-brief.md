# Workspace brief

Status summary for selected workspaces. **This is a workflow template** — run once or schedule with Cron. Not a plugin.

## Steps

1. Refresh digest for each selected workspace (`ncc ai workflows refresh` / GitHub via `gh`).
2. Summarize open PRs, issues, todo/doing tasks.
3. On failure: surface auth/workspace errors — never invent items.
4. If empty: one honest line, stop.

## Rules

- Read-only.
- No merge / no archive / no file writes.
- Time-of-day comes from **Cron / schedule on the template instance**, not from a separate “Morning” plugin.
