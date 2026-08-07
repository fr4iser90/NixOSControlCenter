# Phase 5 — UI integration

Status: **done** (see ROADMAP.md)

**Status:** planned  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phases 1–4 for full IA; **can stub navigation early**  
**Toolkit:** Qt6 / PySide6 (Plasma-friendly), existing `gui.py`

## Problem

The GUI is a single chat window. Agent, tools, jobs, and schedules need a
coherent information architecture so power features are discoverable without
the terminal.

## Goals

1. Multi-section main window (tabs or sidebar).
2. Each roadmap area has a dedicated panel with clear empty states.
3. Shared chrome: model, auth state, busy/stop where relevant.
4. Keyboard habits preserved in Chat (Enter send, Shift+Enter newline).

## Non-goals

- Pixel-perfect custom design system rewrite.
- Web UI as primary (native Qt first).
- Mobile/Kirigami port in this phase.

## Information architecture

```text
┌─────────────────────────────────────────────────────┐
│ NCC AI   [Model ▾]   status/endpoint         [_][□][x]│
├──────────┬──────────────────────────────────────────┤
│ Chat     │  (current transcript + composer)         │
│ Agent    │  goal, budgets, run/stop, live trace     │
│ Tools    │  registry table, MCP add, test           │
│ Jobs     │  runs list + detail/log                  │
│ Schedules│  timers, last run, enable state          │
│ Settings │  optional shortcuts / open config docs   │
└──────────┴──────────────────────────────────────────┘
```

## Features by section

### Chat (existing — polish)

| ID | Feature | Priority |
|----|---------|----------|
| U-C1 | Keep streaming, sessions, vision, confirms | P0 |
| U-C2 | “Run as agent” action from composer/goal | P2 |
| U-C3 | Link to job if a turn spawned agent work | P2 |

### Agent

| ID | Feature | Priority |
|----|---------|----------|
| U-A1 | Goal multiline + Run / Stop | P0 |
| U-A2 | Show maxSteps / policy badges | P0 |
| U-A3 | Live event feed (reuse chat bubbles or denser log) | P0 |
| U-A4 | Open resulting job | P1 |

### Tools

| ID | Feature | Priority |
|----|---------|----------|
| U-T1 | List registry with filters | P0 |
| U-T2 | Enable/disable toggles | P0 |
| U-T3 | Add MCP server dialog | P0 |
| U-T4 | Test tool dialog | P1 |
| U-T5 | Vision/shell warnings | P1 |

### Jobs

| ID | Feature | Priority |
|----|---------|----------|
| U-J1 | Sortable table (status, time, source, goal) | P0 |
| U-J2 | Detail: meta + scrollable log | P0 |
| U-J3 | Retry / reveal in file manager | P1 |

### Schedules

| ID | Feature | Priority |
|----|---------|----------|
| U-S1 | List from config + last job status | P0 |
| U-S2 | Explain “change requires Nix edit/rebuild” | P0 |
| U-S3 | Copy Nix snippet / open propose flow | P1 |

### Settings (light)

| ID | Feature | Priority |
|----|---------|----------|
| U-X1 | Link to USAGE + ROADMAP | P2 |
| U-X2 | Clear credential cache / open config dir | P1 |
| U-X3 | Show effective policy (write/rebuild/agent) | P1 |
| U-X4 | Agent confirm mode: always / writes / never | P0 |
| U-X5 | Presence: Available / Paused (“playing”) + snooze duration | P0 |
| U-X6 | Notification prefs: enable, timeout, onTimeout | P0 |

### Notifications (system — not only in-app)

See [07-notifications-and-presence.md](./07-notifications-and-presence.md).

| ID | Feature | Priority |
|----|---------|----------|
| U-N1 | System tray / desktop notification on pending agent decision | P0 |
| U-N2 | Actions Allow / Block / Wait (or click-through to decision UI) | P0 |
| U-N3 | Badge on Jobs when `waiting_approval` | P1 |
| U-N4 | Quick “Pause agent — I’m playing” from tray/notification | P0 |

## UX principles

- One primary action per section (Send / Run / Add server).
- Destructive actions always confirm (already for write/rebuild).
- Empty states tell the next step (“No MCP servers — Add”).
- Don’t hide Stop while a run is active (Chat + Agent).
- Prefer system palette (Plasma); avoid hardcoded dark-only colors.
- If the main window is **not** focused, prefer **system notifications** over silent waits (phase 7).
- Never auto-Allow on notification timeout unless a dangerous explicit opt-in exists.

## Implementation notes

- Refactor `gui.py` into package `gui/` (`main_window.py`, `chat_page.py`, …)
  when sections land — avoid a 2k-line single file.
- Background workers stay QThread + signals; confirm bridge stays main-thread.
- Pages share one `Settings` / registry / session factory.

## Acceptance criteria

- [ ] User can switch Chat → Tools → Agent → Jobs → Schedules without restart.
- [ ] Agent run visible under Jobs after completion.
- [ ] Tools page can enable a builtin off without restarting the app.
- [ ] Chat regressions: Enter-to-send, streaming, session picker still work.

## Test plan

- Manual GUI checklist per section.
- Smoke: start app headless-safe (`QT_QPA_PLATFORM=offscreen`) for import/construct where possible.
