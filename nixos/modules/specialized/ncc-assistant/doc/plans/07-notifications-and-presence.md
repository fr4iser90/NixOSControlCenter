# Phase 7 — System notifications, presence & interactive approvals

**Status:** planned  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 2 (agent), phase 3 (jobs); pairs with phase 6 (approval queue)  
**UI:** desktop **system notifications** (Plasma/`notify-send` / D-Bus), not only in-app dialogs

## Problem

In-app Qt confirms only work when the NCC window is focused. Real use cases:

- Agent/cron wants to write or rebuild while the user is in a game / another workspace.
- Some users want **every** agent step or every mutating tool to ask first.
- User wants a temporary **“do not disturb / pause agent”** (“playing — don’t execute”).
- User wants **Allow / Block / Wait** without opening the full GUI.

That needs **OS-level notifications** (and a small presence/policy layer the agent respects).

## Goals

1. Desktop notifications for agent events that need a decision.
2. Actions on the notification (or a follow-up popup): **Allow**, **Block**, **Wait / snooze**.
3. **Presence modes** the agent always checks before mutating (and optionally before starting a job).
4. Configurable confirmation strictness: always / writes-only / never (read-only agent).
5. Bridge to phase-6 approval queue when nobody answers in time.

## Non-goals

- Replacing the in-app confirm dialog when the GUI *is* focused (keep both; prefer in-app if window active).
- Mobile push / email (optional later).
- Full focus-steal of fullscreen games beyond “don’t auto-approve”.

## User-facing modes (draft)

| Mode | Behavior |
|------|----------|
| `confirm = "always"` | Every agent tool call (or every mutating one — see below) asks via notification/dialog |
| `confirm = "writes"` | Only `apply_module_config` / `apply_system` / shell / dangerous MCP |
| `confirm = "never"` | No prompts; only allowed if policy is read-only / dry-run |
| Presence `available` | Normal policy |
| Presence `paused` (“playing / DND”) | New jobs don’t start; running agent **blocks** mutating tools; optional snooze all prompts |
| Presence `autonomous` | Only if explicitly enabled + allowWrite; still respects kill-switch |

Presence is **user-local and immediate** (toggle in GUI + notification action + CLI), not only Nix rebuild.

## Notification actions

Primary actions on a decision notification:

| Action | Effect |
|--------|--------|
| **Allow** | Run this tool call once (optionally “Allow for this job”) |
| **Block** | Deny this call; agent continues or aborts per policy |
| **Wait** | Snooze N minutes (default 15/30/60); agent waits or parks job as `waiting_approval` |
| **Open** | Focus Jobs/Agent UI with the pending request |

Optional sticky / persistent notifications on Plasma until answered or timeout.

### Timeout policy

If no answer within `notifyTimeoutSec`:

- `onTimeout = "block"` (safe default)
- `onTimeout = "queue"` → phase-6 approval file, job `partial`/`waiting_approval`
- `onTimeout = "pause"` → set presence paused

Never `onTimeout = "allow"` unless a dedicated dangerous opt-in exists.

## When to notify (events)

| Event | Default notify? |
|-------|-----------------|
| Mutating tool about to run | yes (if confirm mode requires it) |
| Schedule job starting | optional (`notifyOnScheduleStart`) |
| Job succeeded / failed | optional summary |
| Agent waiting on user | yes |
| Kill-switch tripped | yes |

## Features

| ID | Feature | Priority |
|----|---------|----------|
| N1 | Notification backend: `notify-send` + Plasma D-Bus hints; fallback tray/message if unavailable | P0 |
| N2 | Decision protocol: pending id, tool, summary, job id; Allow/Block/Wait | P0 |
| N3 | Agent/runtime consults decision service before mutating tools | P0 |
| N4 | Presence state file `~/.config/ncc-assistant/presence.json` | P0 |
| N5 | GUI: presence toggle (Available / Paused / …) + confirm-mode setting | P0 |
| N6 | Notification actions wired (Plasma actionable notifications or helper dialog) | P0 |
| N7 | CLI: `ncc ai presence pause\|resume`, `ncc ai approve <id> allow\|block` | P1 |
| N8 | “Always confirm agent” preset in Settings | P0 |
| N9 | “Playing — don’t execute” quick action (presence=paused + optional timer) | P0 |
| N10 | If GUI focused → prefer modal dialog; else → system notification | P1 |
| N11 | Timeout → queue/block (integrate phase 6) | P1 |
| N12 | Don’t spam: coalesce multiple tool asks; rate-limit | P2 |

## Config sketch

```nix
agent = {
  confirm = "writes";          # always | writes | never
  notifications = {
    enable = true;
    timeoutSec = 300;
    onTimeout = "block";       # block | queue | pause
    notifyOnScheduleStart = false;
    notifyOnJobEnd = true;
  };
};
```

User-local override (no rebuild):

```json
{
  "presence": "paused",
  "presenceUntil": "2026-08-06T22:00:00+02:00",
  "confirm": "always"
}
```

## Stack notes (Plasma / NixOS)

- Prefer **desktop notifications via D-Bus** (`org.freedesktop.Notifications`).
- Actionable buttons: Plasma supports actions on notifications; if limited, open a small **always-on-top decision dialog** triggered by the notification click.
- Helper user service optional: `ncc-assistant-notifier` listens for pending approvals while GUI closed (cron path).
- Game/fullscreen: still show notification in tray; do **not** auto-allow.

## Relation to other phases

| Phase | Link |
|-------|------|
| 2 Agent | Confirm hook becomes notification-aware, not GUI-only |
| 3 Jobs | Status `waiting_approval`; detail shows pending decision |
| 4 Schedules | Start/end notifications; respect presence before start |
| 5 UI | Settings + presence control + Jobs “pending” badge |
| 6 Hardening | Timeout → approval queue; audit outcomes `allowed_via_notification` / `blocked` / `wait` |

## Acceptance criteria

- [ ] With GUI unfocused, a write tool shows a system notification and waits.
- [ ] **Block** prevents the write; job log records denial.
- [ ] **Wait** snoozes; agent does not execute that tool until resumed or timeout policy applies.
- [ ] Presence `paused` prevents schedule-start and mutating tools.
- [ ] Confirm mode `always` prompts even for read tools (or documented subset).
- [ ] No silent allow on notification timeout by default.

## Test plan

- Headless job + mocked notification bus / file-based decision sink for CI.
- Manual on Plasma: Allow / Block / Wait / pause-while-“playing”.
- Timeout → block and timeout → queue.
