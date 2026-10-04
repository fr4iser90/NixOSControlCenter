# Phase 29 — Desktop companion (avatar + chat overlay)

Status: **implemented (v1.1)**  
**Parent:** [roadmap.md](../roadmap.md)  
**Depends on:** tray (22), GUI chat, presence

## Idea

A small always-on-top **companion window** (Qt overlay today; Plasma plasmoid later):

- Avatar / character that can idle-animate (blink, talk while streaming)
- Compact chat composer + last reply bubble
- Multi-chat tabs (parallel streams)
- Quick panels: history / skills / cron / jobs
- Click → expand to full NCC AI Chat / Templates
- Optional: follow presence (paused = sleepy avatar)

## Non-goals (v1)

- Full VTuber / Live2D pipeline
- Plasma plasmoid (follow-up)
- Always-listening mic by default

## Feasible v1

| Piece | Approach |
|-------|----------|
| Window | Frameless Qt window, translucent bg, always-on-top, `startSystemMove` drag |
| Avatar | Painted canvas; states: idle / thinking / speaking / error / paused |
| Chat | Multi-slot `ChatSession` + streaming; Ctrl+N / Ctrl+Tab |
| Panels | Hist / Skill / Cron / Jobs list overlays |
| Autostart | Optional with `agent.tray` / companion Nix flag |

## Open choices

- 2D sprites vs painted avatar first
- Share process with tray vs separate `ncc-assistant-companion`
- Wayland layer-shell / Plasma plasmoid packaging

## Shipped

```bash
ncc ai companion
# or: ncc-assistant-companion
```

- Frameless always-on-top; translucent chrome; avatar + glass panel
- Wayland-safe drag (`startSystemMove`); keyboard focus on input
- Multi-chat tabs; background busy chats keep streaming
- Panels: session history, skills/templates, schedules, jobs
- Pause / Resume presence; Open full UI
- Desktop action + tray menu entry

## Acceptance

- [x] Companion opens without full GUI shell
- [x] Send message → stream → avatar “speaking” state
- [x] Pause presence reflected in avatar
- [x] No secrets in screenshots/logs (errors truncated)
- [x] Can type in composer; can drag window (incl. Wayland)
- [x] Switch / create multiple chats

## Follow-ups

- Plasma plasmoid shell (same Python core)
- Sprite / Lottie skins
- Optional xdg autostart when `agent.companion.enable = true`
- In-panel cron/job actions (not only “open full UI”)
- Shell IA (sessions dropdown, resize, workspace/MCP/tools icons) → [32-companion-shell-ux](./32-companion-shell-ux.md)
