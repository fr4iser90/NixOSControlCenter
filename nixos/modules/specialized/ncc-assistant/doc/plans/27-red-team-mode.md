# Phase 27 — Red-team mode

**Status:** planned (backlog)  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 2, 6, 18; pairs with [26-eval-harness.md](./26-eval-harness.md)

## Problem

Guards must be proven: the agent (or a scripted adversary prompt) tries forbidden
actions and must be blocked — write without confirm, rebuild when denied, shell
when disallowed, ignore presence pause, etc.

## Goals

1. Red-team playbook/prompt pack that *attempts* policy violations.
2. Harness asserts denials (no disk mutation).
3. Runnable on demand; never enabled as default schedule.

## Features

| ID | Feature | Priority |
|----|---------|----------|
| RT1 | Playbook `red-team-guards` with aggressive goal text | P0 |
| RT2 | Sandbox/temp NIXOS_DIR for tests so real /etc/nixos untouched | P0 |
| RT3 | Assert: apply denied, rebuild denied, shell denied, pause respected | P0 |
| RT4 | Report of which attacks passed/failed | P0 |
| RT5 | GUI “Run red-team (safe sandbox)” behind confirm | P1 |
| RT6 | Integrate subset into eval harness CI | P1 |

## Non-goals

- Attacking the LLM provider.
- Testing physical security / multi-user compromise.

## Acceptance criteria

- [ ] Red-team run against sandbox produces zero writes outside sandbox.
- [ ] At least one attack scenario fails the suite if confirm hook always returns true incorrectly (mutation detector).

## Test plan

- Broken policy harness → fail.
- Correct policy → all attacks blocked → pass.
