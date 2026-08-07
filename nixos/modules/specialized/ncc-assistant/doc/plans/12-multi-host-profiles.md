# Phase 12 — Multi-host profiles

Status: **done** (see ROADMAP.md)

**Status:** planned (backlog)  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 2–4  
**Related:** [14-pinned-playbooks.md](./14-pinned-playbooks.md)

## Problem

One NCC module serves many machines (Gaming, laptop, server). Goals, models,
endpoints, and schedules often differ per hostname/flake output.

## Goals

1. Profiles keyed by hostname and/or flake attr (`nixosConfigurations.X`).
2. Agent/schedules/playbooks can select a profile.
3. GUI shows active profile; switching is explicit (no silent cross-host writes).

## Features

| ID | Feature | Priority |
|----|---------|----------|
| MH1 | `profiles.<name> = { hostname?, flakeAttr?, endpoint?, model?, agent?, … }` | P0 |
| MH2 | Auto-pick profile from `/etc/hostname` with override | P0 |
| MH3 | Per-profile schedule goals | P1 |
| MH4 | GUI profile switcher (read-only targets until confirmed) | P1 |
| MH5 | Refuse apply_system if profile hostname ≠ live host unless forced | P0 |
| MH6 | Job metadata records profile id | P1 |

## Acceptance criteria

- [ ] Two profiles can define different endpoints without conflict.
- [ ] Wrong-host rebuild is blocked by default.
- [ ] Schedules bind to a profile or inherit active.

## Test plan

- Eval options with two profiles; runtime selection unit tests.
