# Phase 13 — Knowledge sync (GUI)

**Status:** planned (backlog)  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** packaged knowledge under module; optional repo generators  
**Related:** [10-config-drift-health.md](./10-config-drift-health.md), [26-eval-harness.md](./26-eval-harness.md)

## Problem

Knowledge/registries can go stale relative to discovered modules. Operators need
a GUI/CLI action to refresh indexes without hunting shell scripts.

## Goals

1. “Sync knowledge” action regenerates or reloads what the assistant searches.
2. Clear status: last sync time, errors, what changed.
3. Respect flake purity: sync may update **user** overlay or prompt rebuild if
   store knowledge is immutable.

## Features

| ID | Feature | Priority |
|----|---------|----------|
| KS1 | GUI button + `ncc ai knowledge sync` | P0 |
| KS2 | Prefer regenerating into `~/.config/ncc-assistant/knowledge-overlay/` | P0 |
| KS3 | Fallback: document “rebuild to refresh store knowledge” | P0 |
| KS4 | Show diff summary (new modules in registry) | P1 |
| KS5 | Auto-hint in health report when discovery ≫ knowledge | P2 |

## Design note

Store paths are immutable. Sync must either (a) write a user overlay that
`search_knowledge` prefers, or (b) only validate and tell user to rebuild after
repo generators ran in the git tree.

## Acceptance criteria

- [ ] After sync, search finds a newly added overlay document.
- [ ] Failure is visible in GUI (not only journal).

## Test plan

- Overlay write + search path precedence.
