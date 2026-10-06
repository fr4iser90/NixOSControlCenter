# Autonomous agent (per-task execute → PR)

Professional loop for one workspace. **One task = one branch = one PR.**

## CLI (prefer these)

```bash
ncc ai workflow audit --workspace ID --json
ncc ai workflow plan --workspace ID
ncc ai workflow resume --workspace ID --json
ncc ai workflow task-start --workspace ID [--task TASK]
# … implement ONLY that gap …
ncc ai workflow task-finish --workspace ID --task TASK -m "…"
```

`task-finish` **hard-fails** if validators fail → no PR. Marks task `done` + writes progress checkpoint on success.

## Rules

1. Never merge / bump / force-push.
2. Never open a mega-PR spanning multiple gaps.
3. Resume via `workflow resume` / `task-start` without `--task` if a doing task exists.
4. Gap identity is `gap:<id>` on the Daily task links — not title strings.
5. Stop after `maxTasks` or when no open p0/p1 left.

Point user to `autonomous-agent-ship` with confirm=CONFIRM for merge.
