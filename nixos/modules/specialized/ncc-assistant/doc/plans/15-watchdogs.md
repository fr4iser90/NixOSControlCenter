# Phase 15 — Watchdogs (event triggers)

**Status:** planned (backlog)  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 2–4, phase 7 (notify)  
**Related:** [10-config-drift-health.md](./10-config-drift-health.md), [14-pinned-playbooks.md](./14-pinned-playbooks.md)

## Problem

Calendar schedules miss “something just broke”. Users want triggers: failed
rebuild, disk full, channel bump available, etc.

## Goals

1. Event sources → queue agent job / playbook / notification.
2. Deduplicate storms (N events → one job).
3. Same policy/presence gates as schedules.

## Features

| ID | Feature | Priority |
|----|---------|----------|
| W1 | Watchdog config: event → playbook/goal + policy | P0 |
| W2 | Sources v1: systemd unit failure (nixos-rebuild), journal match | P0 |
| W3 | Sources v2: disk threshold, `ncc` channel-check result | P1 |
| W4 | Cooldown / debounce per watchdog id | P0 |
| W5 | Respect presence paused + kill-switch | P0 |
| W6 | GUI: list watchdogs + last fire | P1 |

## Example events

- `rebuild-failed`
- `disk-root-above-90`
- `channel-bump-available`
- `preflight-failed` (if wired)

## Acceptance criteria

- [ ] Simulated rebuild failure starts at most one job per cooldown.
- [ ] Paused presence prevents start but can still notify (configurable).

## Test plan

- Fake event injector; debounce unit tests.
