# Phase 22 — System tray daemon

Status: **done** (see ROADMAP.md)

**Status:** planned (backlog)  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 7 (notifications/presence), phase 3 (jobs)  
**Related:** [23-global-shortcuts.md](./23-global-shortcuts.md)

## Problem

Approvals and presence need to work without the full chat window open —
especially for cron/agent while gaming or working elsewhere.

## Goals

1. Lightweight tray/indicator process: presence, pending approvals, pause.
2. Can start independently of main GUI (`ncc-assistant-tray`).
3. Opens main window on demand; shares state files with phase 7.

## Features

| ID | Feature | Priority |
|----|---------|----------|
| TR1 | Tray icon with menu: Available/Paused, Pending N, Open NCC AI | P0 |
| TR2 | Show pending approval count from approvals/jobs | P0 |
| TR3 | Quick Allow/Block last pending (or open decision UI) | P1 |
| TR4 | Autostart optional via Nix `agent.tray.enable` / xdg autostart | P1 |
| TR5 | Single-instance; talks to main GUI via D-Bus or files | P0 |

## Acceptance criteria

- [ ] Tray alone can set presence=paused; agent respects it.
- [ ] Pending approval visible without main window.

## Test plan

- File-based presence write from tray code path.
- Manual Plasma tray smoke.
