# Phase 16 — Visible budgets

**Status:** planned (backlog)  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 2–3, phase 7  
**Related:** [02-agent-mode.md](./02-agent-mode.md)

## Problem

Budgets (`maxSteps`, tokens, timeout) exist in plans but users don’t see remaining
headroom during a run — especially in notifications.

## Goals

1. Live budget counters in Agent GUI and job detail.
2. Include remaining steps/time in decision notifications.
3. Soft warn at 80%; hard stop already in agent loop.

## Features

| ID | Feature | Priority |
|----|---------|----------|
| B1 | Track steps used / remaining; optional token estimate from API usage | P0 |
| B2 | Agent header: `steps 5/24 · ~2m left` | P0 |
| B3 | Notification body includes budget snippet | P1 |
| B4 | Job meta stores budget snapshot + final consumption | P0 |
| B5 | CLI `--print-budget` on running job | P2 |

## Acceptance criteria

- [ ] UI updates every step.
- [ ] Hit maxSteps → status explains budget exhaustion (not generic error).

## Test plan

- Agent with maxSteps=2; assert counter and stop reason.
