# Phase 8 — Diff-Review UI

Status: **done** (see ROADMAP.md)

**Status:** planned (backlog)  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 1–2 (propose/apply tools), phase 5 (GUI shell)  
**Related:** [09-rollback-assistant.md](./09-rollback-assistant.md)

## Problem

`propose_config_patch` returns text diffs in chat/tool results. Users need a clear
side-by-side review and selective apply — especially for agent-proposed changes.

## Goals

1. Diff-Review panel (or modal): current vs proposed Nix leaf.
2. Actions: **Apply selected**, Reject, Copy, Open in editor.
3. Works for chat tool results, agent jobs, and approval-queue items (phase 6).

## Features

| ID | Feature | Priority |
|----|---------|----------|
| D1 | Unified diff + optional side-by-side view | P0 |
| D2 | Multi-hunk / multi-file list when job proposes several modules | P0 |
| D3 | Apply selected module paths via `apply_module_config` + confirm | P0 |
| D4 | Syntax highlight for Nix (basic) | P1 |
| D5 | “Apply all” with extra confirm | P1 |
| D6 | Link from Jobs / Approvals / Chat tool bubble → Diff-Review | P0 |

## Acceptance criteria

- [ ] User can apply one of N proposed leaves without applying others.
- [ ] Reject discards proposal without writing.
- [ ] Apply still respects allowWrite + confirm/notification policy.

## Test plan

- Fixture patches; GUI apply calls facade once per selected path.
