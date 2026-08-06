# Phase 9 — Rollback assistant

**Status:** planned (backlog)  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 2–3; system-manager backups / generations  
**Related:** [08-diff-review-ui.md](./08-diff-review-ui.md)

## Problem

After a write or rebuild, users need a guided path back: NixOS generation and/or
NCC config backup — without memorizing CLI.

## Goals

1. After successful `apply_module_config` / `apply_system`, offer rollback hints.
2. Tools + GUI: list recent backups/generations, propose restore steps.
3. Never silent rebuild-to-previous; always confirm (phase 7 notifications OK).

## Features

| ID | Feature | Priority |
|----|---------|----------|
| R1 | Builtin tool `list_config_backups` / wrap `ncc` backup listing | P0 |
| R2 | Builtin tool `list_boot_generations` (read-only) | P0 |
| R3 | Post-write GUI toast/card: “Undo config write” / “Rollback generation” | P0 |
| R4 | Guided restore: restore leaf from backup via facade (confirm) | P1 |
| R5 | Guided generation switch: document/`ncc` boot entry select (confirm+rebuild policy) | P1 |
| R6 | Job metadata stores pre-change snapshot path when available | P1 |

## Acceptance criteria

- [ ] After a config write, UI shows at least one concrete undo path.
- [ ] Rollback write requires same guards as apply.
- [ ] Read-only listing works with `agent.allowWrite = false`.

## Test plan

- Mock backup dir; tool lists entries.
- Confirm denied when policy forbids write.
