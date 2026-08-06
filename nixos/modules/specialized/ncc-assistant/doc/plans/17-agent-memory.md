# Phase 17 — Agent memory

**Status:** planned (backlog)  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 2–3  
**Related:** [12-multi-host-profiles.md](./12-multi-host-profiles.md), [14-pinned-playbooks.md](./14-pinned-playbooks.md)

## Problem

Users repeat preferences (“dry-run on Sundays”, “never touch chronicle”). Chat
sessions don’t share durable notes across agent jobs.

## Goals

1. Small durable memory store the agent may read/write with policy.
2. Inject relevant notes into agent system prompt (bounded size).
3. GUI to view/edit/delete memories; never store secrets.

## Features

| ID | Feature | Priority |
|----|---------|----------|
| M1 | `~/.config/ncc-assistant/memory.jsonl` or sqlite | P0 |
| M2 | Notes: text, tags, host/profile scope, created | P0 |
| M3 | Tools `memory_list` / `memory_add` / `memory_forget` (guarded) | P0 |
| M4 | Auto-inject top-N notes into agent prompt | P0 |
| M5 | GUI Memory page | P1 |
| M6 | Redact patterns (keys, tokens) on write | P0 |
| M7 | Optional “suggest memory” after job | P2 |

## Non-goals

- Full RAG over home directory.
- Unbounded autobiography of the user.

## Acceptance criteria

- [ ] Note survives app restart and appears in next agent prompt.
- [ ] Secret-like strings rejected or redacted.
- [ ] User can delete a note from GUI.

## Test plan

- Add/list/forget; prompt injection size cap.
