# Phase 20 — Per-tool rate limits & cost estimates

**Status:** planned (backlog)  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 1–3, phase 16 (budgets)  
**Related:** [18-safe-tool-profiles.md](./18-safe-tool-profiles.md)

## Problem

Agents can hammer tools or blow token budgets. Operators want per-tool limits and
rough cost visibility (API usage / step cost).

## Goals

1. Per-tool rate limits (calls per job / per minute).
2. Optional cost estimate from provider usage fields or heuristic $/1k tokens.
3. Surface estimates in Agent UI + job summary.

## Features

| ID | Feature | Priority |
|----|---------|----------|
| RC1 | Registry metadata `maxCallsPerJob`, `minIntervalMs` | P0 |
| RC2 | Enforce limits in ToolRuntime.call | P0 |
| RC3 | Parse `usage` from LLM responses when present | P1 |
| RC4 | Heuristic token estimate if no usage | P2 |
| RC5 | Job summary: tools called, tokens, est. cost | P1 |
| RC6 | GUI warning when approaching limit | P1 |

## Acceptance criteria

- [ ] Exceeding maxCallsPerJob returns structured error to the model.
- [ ] Job result includes usage totals when API provides them.

## Test plan

- Tool with maxCallsPerJob=1; second call denied.
