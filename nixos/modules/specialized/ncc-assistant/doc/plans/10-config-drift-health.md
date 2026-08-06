# Phase 10 — Config drift / health report

**Status:** planned (backlog)  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 1 (tools), phase 3–4 (jobs/schedules), knowledge registries  
**Related:** [14-pinned-playbooks.md](./14-pinned-playbooks.md), [15-watchdogs.md](./15-watchdogs.md)

## Problem

Drift accumulates: disabled modules still huge in config, missing leaves, channel
pin mismatches, stale options. Users want a periodic readable health report.

## Goals

1. Builtin (or playbook) that produces a structured health report.
2. Checks: disabled-but-present modules, missing seeded leaves, flake pin /
   channel hints, basic parse failures.
3. Runnable on demand + as schedule goal; results stored as job artifact.

## Features

| ID | Feature | Priority |
|----|---------|----------|
| HLT1 | Tool `config_health_report` → JSON + markdown summary | P0 |
| HLT2 | Detect disabled specialized modules with large attrsets | P1 |
| HLT3 | Detect discovered modules missing from monolith/split | P0 |
| HLT4 | Flag allowUnfree / layout / configVersion inconsistencies | P1 |
| HLT5 | GUI: Health page or Jobs report viewer | P1 |
| HLT6 | Schedule template “weekly health (read-only)” | P1 |

## Acceptance criteria

- [ ] Report runs read-only under agent dry-run / allowWrite=false.
- [ ] Missing module leaf appears as finding after seed gap simulation.
- [ ] Output suitable for notification summary (short) + full job log.

## Test plan

- Fixture systemConfig with intentional gaps.
- Snapshot markdown sections.
