# Phase 11 — Preflight as tool

Status: **done** (see ROADMAP.md)

**Status:** planned (backlog)  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 1–2; existing `prebuild-checks` / system-checks  
**Related:** [18-safe-tool-profiles.md](./18-safe-tool-profiles.md) (`ops` profile)

## Problem

Rebuilds should be preceded by the same preflight NCC already runs in
`nixos-rebuild` wrappers. The agent currently has `validate_config` but not full
preflight (CPU/GPU/memory/users, etc.).

## Goals

1. Expose preflight as a builtin tool the agent/chat can call.
2. `apply_system` policy can require recent successful preflight (optional).
3. Surface preflight output in Jobs / Diff-adjacent UI cleanly (unified log schema).

## Features

| ID | Feature | Priority |
|----|---------|----------|
| PF1 | Tool `run_preflight` → structured `[ OK ]`/`[WARN]`/`[ERROR]` JSON | P0 |
| PF2 | Wrap existing prebuild-check scripts (no duplicate logic) | P0 |
| PF3 | Option `agent.requirePreflightBeforeRebuild` | P1 |
| PF4 | GUI: show last preflight on Agent/Jobs detail | P1 |
| PF5 | Verbose flag for detail lines (match CLI `--verbose`) | P2 |

## Acceptance criteria

- [ ] Agent can run preflight without allowWrite.
- [ ] Failed preflight blocks rebuild when require-flag is on.
- [ ] Output matches quiet schema used by system-update.

## Test plan

- Mock failing users check → tool returns ok=false.
- Policy gate on apply_system.
