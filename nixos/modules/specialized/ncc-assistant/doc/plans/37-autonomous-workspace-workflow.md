# Phase 37 — Autonomous workspace workflow

Status: **done** (pro loop: audit → plan → per-task branch/PR → ship+CONFIRM)  
**Parent:** [roadmap.md](../roadmap.md)  
**Depends on:** workspaces (28), workflows/rulebooks (34), companion (29–33)  
**Related:** [36-feature-plugins.md](./36-feature-plugins.md)

## Problem

Users want Companion to **manage local git workspaces**: analyze, fill legal stubs /
AGENTS/skills, derive tasks, then **one task → one branch → validate → PR →
merge/version** with a hard confirm gate and resume checkpoints.

## Goals

1. Deterministic **workspace audit** (file/layout probes → gap enums).
2. **Plan**: Daily tasks with stable `gap:<id>` links (idempotent).
3. Templates: `workspace-audit`, `autonomous-agent-run`, `autonomous-agent-ship`, …
4. CLI: `audit|plan|status|next|resume|task-start|task-finish|branch|validate|commit|pr|merge|bump`.
5. Companion Daily actions for the active workspace.
6. Merge/bump require literal confirm token `CONFIRM`.
7. `task-finish` refuses PR if validators fail; progress JSON for resume.

## Pipeline

```text
ANALYZE → PLAN (gap:<id> tasks)
       → LOOP: task-start → implement → task-finish (validate hard → PR)
       → SHIP (merge / bump) only with confirm=CONFIRM
```

## Gap checks (enums)

| id | Missing when |
|----|----------------|
| `agents-md` | no `AGENTS.md` |
| `skills` | no `.agents/skills/` (or empty) |
| `impressum` | no impressum path match |
| `privacy` | no privacy.md / datenschutz.md path match |
| `roadmap-doc` | no `doc/roadmap.md` / `ROADMAP.md` |
| `license` | no `LICENSE` / `LICENSE.md` |
| `precommit` | no `.pre-commit-config.yaml` |
| `githooks` | no `.githooks/` |
| `readme` | no `README.md` |

## Confirm / validate policy

- `task-finish` → validate must pass or no PR
- `ncc ai workflow merge --confirm CONFIRM`
- `ncc ai workflow bump --confirm CONFIRM`
- Template `autonomous-agent-ship` param `confirm` enum `NO|CONFIRM` (default NO)

## Non-goals

- Binding legal advice (stubs only).
- Force-push.
- Fleet parallel across all workspaces (still one active workspace).

## Acceptance

- [x] audit/plan/status + gap: links
- [x] next/resume + progress checkpoint
- [x] task-start / task-finish (validate gate)
- [x] merge/bump gated by CONFIRM
- [x] Companion Daily buttons
- [x] gates green
