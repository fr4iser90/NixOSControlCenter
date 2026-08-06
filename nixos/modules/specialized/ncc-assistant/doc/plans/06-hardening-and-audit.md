# Phase 6 — Hardening & audit

**Status:** planned  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 2 (+ 4 for schedule-specific rules)

## Problem

Agent + schedules increase blast radius. Need dry-run, approvals, audit, and
hard stops so “automatic” never means “unsupervised root changes”.

## Goals

1. **Dry-run** mode: tools that mutate become propose-only.
2. **Approval queue**: unattended runs can stage writes for GUI apply.
3. **Audit log** of sensitive actions.
4. **Kill-switch** and hard budgets for unattended execution.
5. Assertions / docs for dangerous schedule combinations.
6. **Interactive approvals via system notifications** when the GUI is unfocused
   (Allow / Block / Wait) — details in [07-notifications-and-presence.md](./07-notifications-and-presence.md).

## Non-goals

- Formal certification / multi-user RBAC server.
- Secret management redesign (keep sops/`apiKeyFile`/cache model).

## Features

| ID | Feature | Priority |
|----|---------|----------|
| H1 | Global or per-job `dryRun` — `apply_*` returns preview only | P0 |
| H2 | Approval queue dir `~/.config/ncc-assistant/approvals/` | P1 |
| H3 | GUI: pending approvals → Apply / Dismiss | P1 |
| H4 | Append-only audit log (JSONL) for writes/rebuilds/MCP shell | P0 |
| H5 | Kill-switch file `~/.config/ncc-assistant/DISABLE` aborts agent/cron | P0 |
| H6 | Hard caps: max concurrent jobs = 1; max schedule write=false assert | P0 |
| H7 | Rate limit / cooldown between schedule fires | P2 |
| H8 | Redact secrets in logs (api keys, env) | P0 |
| H9 | `ncc ai agent run --dry-run` | P0 |
| H10 | Notification timeout → `queue` integrates with H2/H3 | P1 |
| H11 | Audit outcomes include `allowed_via_notification` / `blocked` / `wait` / `presence_paused` | P0 |

## Policy matrix (documentation)

| Caller | allowWrite chat | allowWrite agent | dryRun | Result of apply_module_config |
|--------|-----------------|------------------|--------|-------------------------------|
| Chat GUI | true | n/a | false | confirm dialog → write |
| Agent GUI | true | true | false | confirm → write |
| Agent cron | n/a | true | false | write **or** notify+wait **or** queue if `requireApproval` / phase 7 |
| Agent cron | n/a | false | * | always denied |
| Any | * | * | true | preview only |
| Presence paused | * | * | * | mutating tools denied / jobs not started |

Recommended default for schedules: `allowWrite=false`, `dryRun=true` until user
opts into approvals or explicit write. Prefer `notifications.onTimeout = "block"`
or `"queue"`, never silent allow.

## Audit event sketch

```json
{
  "ts": "…",
  "actor": "agent|chat|mcp|timer",
  "jobId": "…",
  "tool": "apply_module_config",
  "module_path": "modules/specialized/…",
  "outcome": "written|denied|queued|cancelled",
  "dryRun": false
}
```

## Acceptance criteria

- [ ] Dry-run agent cannot change systemConfig on disk.
- [ ] Kill-switch stops new agent/timer runs within one process check.
- [ ] Audit log entries for every write attempt (including denied).
- [ ] Nix eval warns/fails on schedule with `allowRebuild=true` unless explicitly opted in (e.g. `forceDangerous = true`).

## Test plan

- Policy matrix automated tests.
- Kill-switch + lock interaction.
- Redaction unit tests on log writer.
