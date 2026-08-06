# Phase 4 — Schedules & timers (cron-like)

**Status:** planned  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 2 + 3  
**Related UI:** phase 5 Schedules section

## Problem

Users want NCC agent work **without opening the GUI** — e.g. weekly hygiene,
drift reports — with the same guards as interactive agent.

## Goals

1. Declarative schedules in module config (Nix/systemd) as SSOT.
2. Optional user-local schedule overlays for experimentation.
3. Each tick starts an agent job (phase 3) with schedule id in metadata.
4. GUI **Schedules**: enable view, next run, last job link, logs.

## Non-goals

- Distributed cron across machines.
- Default-on write/rebuild schedules.
- Calendar UI as fancy as KOrganizer (simple list + fields first).

## Decision: scheduling backend

| Option | Pros | Cons |
|--------|------|------|
| **A. Nix + systemd timer** | Declarative, survives reboots, NCC-native | Needs rebuild to change |
| **B. User systemd --user** | Fast iterate, no rebuild | Easy to drift from systemConfig |
| **C. Classical cron** | Familiar | Worse secrets/env integration on NixOS |

**Recommendation:** implement **A** as primary; allow **B** read of
`~/.config/ncc-assistant/schedules/*.json` as overlay for goals/flags only
(timers still from A), or generate user timers behind an `agent.userSchedules`
experimental flag.

## Features

| ID | Feature | Priority |
|----|---------|----------|
| S1 | Nix `agent.schedules.<name>` options | P0 |
| S2 | `systemd.services.ncc-assistant-agent-job@` + timers | P0 |
| S3 | Pass goal/policy via unit `Environment=` or drop-in JSON | P0 |
| S4 | Job `source=timer`, `schedule=<name>` | P0 |
| S5 | GUI Schedules list (from evaluated config + last job) | P0 |
| S6 | GUI: propose Nix snippet for new schedule (write via tool/confirm) | P1 |
| S7 | User-local overlay JSON | P2 |
| S8 | notify-send / journal summary on failure | P2 |
| S9 | Missed schedule policy (persist timers) | P1 |

## Nix options (draft)

```nix
agent.schedules.weekly-hygiene = {
  enable = true;
  onCalendar = "Sun *-*-* 10:00:00";
  persistent = true;
  goal = "Read-only: summarize disabled modules and config drift risks.";
  maxSteps = 16;
  allowWrite = false;
  allowRebuild = false;
  # model = null;  # inherit assistant model
  # user = "fr4iser";  # run as user for home/.config access
};
```

## Security defaults

- Schedule `allowWrite` default **false**; module should `assertions` warn if
  `allowRebuild = true` on any schedule.
- Unit should load credentials from `apiKeyFile` or documented env; no TTY.
- If auth missing → job `failed` with clear error (no hang on getpass).

## Acceptance criteria

- [ ] Enabling a schedule creates a timer; `systemctl list-timers` shows it.
- [ ] Firing creates a phase-3 job with schedule name.
- [ ] Read-only schedule cannot write config even if chat allowWrite is true.
- [ ] GUI shows last status for each schedule.

## Test plan

- NixOS VM or dry-activate: unit/timer present.
- Manual `systemctl start ncc-assistant-agent-job@weekly-hygiene.service`.
- Failure path: no credentials.
