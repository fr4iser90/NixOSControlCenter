# Phase 18 — Safe tool profiles

**Status:** planned (backlog)  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 1 (registry), phase 2 (agent)  
**Related:** [11-preflight-as-tool.md](./11-preflight-as-tool.md), [14-pinned-playbooks.md](./14-pinned-playbooks.md)

## Problem

AllowWrite/allowRebuild booleans are coarse. Users need named presets that set
tool allowlists + confirm mode together.

## Goals

1. Built-in profiles: `read-only`, `config-writer`, `ops` (rebuild).
2. Agent/playbook/schedule references a profile.
3. GUI shows active profile badge; switching asks confirm if upgrading power.

## Features

| ID | Feature | Priority |
|----|---------|----------|
| SP1 | Profile schema: allowlist/denylist, allowWrite, allowRebuild, confirm, dryRun | P0 |
| SP2 | Builtin `read-only` — no apply_*/shell | P0 |
| SP3 | Builtin `config-writer` — apply_module_config allowed, no apply_system | P0 |
| SP4 | Builtin `ops` — rebuild allowed + requirePreflight optional | P0 |
| SP5 | User-defined profiles in config dir | P1 |
| SP6 | GUI selector; upgrade to `ops` confirms | P0 |

## Acceptance criteria

- [ ] `read-only` agent cannot call apply_module_config even if module allowWrite true.
- [ ] Playbook can pin `read-only` regardless of session defaults.

## Test plan

- Matrix: profile × tool name → allowed boolean.
