# Phase 23 — Global shortcuts

Status: **done** (see ROADMAP.md)

**Status:** planned (backlog)  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 7, phase 22 (tray) preferred  
**Related:** [22-system-tray-daemon.md](./22-system-tray-daemon.md)

## Problem

Pause agent / open pending approval should be reachable without finding the window
— via Plasma global shortcuts.

## Goals

1. Register shortcuts: Pause/Resume presence, Open pending approval, Open NCC AI.
2. Configurable key sequences; document defaults.
3. Works while tray or main app runs.

## Features

| ID | Feature | Priority |
|----|---------|----------|
| GS1 | Shortcut: toggle presence paused | P0 |
| GS2 | Shortcut: open/focus pending approval | P0 |
| GS3 | Shortcut: show main window | P1 |
| GS4 | Settings UI to rebind (or document Plasma System Settings) | P1 |
| GS5 | Conflict detection / fail soft if grab fails | P2 |

## Defaults (draft)

- `Meta+Shift+P` — pause/resume agent presence  
- `Meta+Shift+A` — pending approval  
- `Meta+Shift+N` — open NCC AI  

## Acceptance criteria

- [ ] Pause shortcut sets presence file; running agent blocks mutates.
- [ ] Approval shortcut focuses decision UI or tray popup.

## Test plan

- Manual Plasma binding; unit test command handlers without WM.
