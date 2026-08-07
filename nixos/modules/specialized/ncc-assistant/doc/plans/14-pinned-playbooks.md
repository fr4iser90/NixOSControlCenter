# Phase 14 — Pinned prompts / playbooks

Status: **done** (see ROADMAP.md)

**Status:** planned (backlog)  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 2 (agent), phase 3 (jobs)  
**Related:** [10-config-drift-health.md](./10-config-drift-health.md), [18-safe-tool-profiles.md](./18-safe-tool-profiles.md)

## Problem

Repeating good goals by hand is friction. Users want one-click agent runs like
“Disable unused specialized modules (dry-run)”.

## Goals

1. Playbook library: title, goal text, policy defaults, optional schedule bind.
2. Ship a few built-in playbooks; allow user JSON playbooks.
3. GUI: pin/favorites on Agent page; one click → job.

## Features

| ID | Feature | Priority |
|----|---------|----------|
| PB1 | Schema `playbooks/*.json` under config + module defaults | P0 |
| PB2 | Fields: id, title, goal, dryRun, allowWrite, maxSteps, profile, tags | P0 |
| PB3 | Builtin set (health dry-run, unused modules dry-run, explain packages, …) | P0 |
| PB4 | GUI list + Run + Pin | P0 |
| PB5 | CLI `ncc ai playbook run <id>` | P1 |
| PB6 | “Create playbook from last agent goal” | P2 |

## Example

```json
{
  "id": "unused-modules-dry-run",
  "title": "Unused specialized modules (dry-run)",
  "goal": "List specialized modules with enable=false and large configs; propose cleanup; do not write.",
  "dryRun": true,
  "allowWrite": false,
  "maxSteps": 12,
  "tags": ["maintenance", "safe"]
}
```

## Acceptance criteria

- [ ] One click starts agent job with playbook policy, not chat allowWrite alone.
- [ ] User can add a playbook without rebuild (user dir).

## Test plan

- Load builtins + user override; run creates job with playbook id in meta.
