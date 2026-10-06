# Autonomous agent (ship)

Merge + optional version bump. **Confirm gate is mandatory.**

## Rules

1. `confirm` param must be exactly `CONFIRM` or refuse.
2. Prefer merging the PR URL attached as `pr:…` on the finished task, or current branch PR.
3. Merge only via `ncc ai workflow merge --confirm CONFIRM`.
4. Bump only via `ncc ai workflow bump --confirm CONFIRM` when `doBump=yes`.
5. Never force-push. Never invent confirm.
6. Report PR URL / merge result / new version.
7. Check `ncc ai workflow resume --json` after merge for remaining tasks.
