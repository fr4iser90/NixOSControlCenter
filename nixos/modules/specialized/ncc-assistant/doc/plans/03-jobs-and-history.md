# Phase 3 — Jobs & history

**Status:** planned  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 2  
**Unblocks:** phase 4 (schedules need last-run visibility), phase 5 (Jobs UI)

## Problem

Agent/chat sessions are not the same as **runs**. Cron and on-demand agents need
durable artifacts: logs, status, diffs, exit reason — inspectable in the UI.

## Goals

1. Job store under `~/.config/ncc-assistant/jobs/<id>/`.
2. Every agent run (CLI/GUI/cron) creates/updates a job.
3. GUI **Jobs** list: status, goal, timestamps, open log, retry.
4. Optional link from chat (“promote turn to agent job”) later.

## Non-goals

- Central multi-host job server.
- Infinite retention (need prune policy).

## Features

| ID | Feature | Priority |
|----|---------|----------|
| J1 | Job schema: id, source (gui/cli/timer), goal, status, model, policy snapshot | P0 |
| J2 | `events.jsonl` or `log.txt` stream of status/tool/assistant | P0 |
| J3 | `result.json` (ok, summary, error, steps used) | P0 |
| J4 | Store proposed diffs / write attempts metadata | P1 |
| J5 | CLI `ncc ai jobs list\|show\|log` | P1 |
| J6 | GUI Jobs table + detail view | P0 |
| J7 | Retry job (re-run same goal + policy) | P1 |
| J8 | Prune: keep last N or older than D days | P2 |
| J9 | Lockfile per host for concurrent agent runs | P0 |

## On-disk layout (draft)

```text
~/.config/ncc-assistant/jobs/
  20260806-195100-ab12cd/
    meta.json
    events.jsonl
    result.json
    messages.json      # optional full transcript
```

`meta.json` sketch:

```json
{
  "id": "20260806-195100-ab12cd",
  "source": "gui",
  "goal": "…",
  "status": "running",
  "created": "…",
  "updated": "…",
  "model": "…",
  "endpoint": "…",
  "policy": { "allowWrite": false, "allowRebuild": false, "maxSteps": 24 },
  "schedule": null
}
```

Statuses: `queued` | `running` | `succeeded` | `failed` | `cancelled` | `partial`.

## Concurrency

- Global lock: `~/.config/ncc-assistant/agent.lock` (or flock on jobs dir).
- Second run: fail fast or queue (v1: fail fast with clear error).

## Acceptance criteria

- [ ] GUI agent run appears in Jobs with live-updating status.
- [ ] CLI can `show` a finished job and print summary.
- [ ] Two overlapping agents: second fails with lock error (v1).
- [ ] Sessions remain separate from jobs (chat history unchanged).

## Test plan

- Create job, append events, finalize result.
- Lock contention test.
- UI loads truncated log for large jobs.
