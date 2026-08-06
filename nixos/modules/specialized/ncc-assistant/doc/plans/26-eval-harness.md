# Phase 26 — Eval harness

**Status:** planned (backlog)  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** knowledge + tools stable; helpful after phase 13  
**Related:** [13-knowledge-sync.md](./13-knowledge-sync.md), [27-red-team-mode.md](./27-red-team-mode.md)

## Problem

Regressions in prompts/tools/knowledge are invisible until users complain.
Need fixed questions and snapshot checks.

## Goals

1. Suite of eval cases: question → expected tool use and/or answer constraints.
2. Runnable in CI or `ncc ai eval` against a mock or real endpoint.
3. Knowledge-only checks that don’t need an LLM (registry invariants).

## Features

| ID | Feature | Priority |
|----|---------|----------|
| EV1 | Case format: id, prompt, expectTools?, expectSubstring?, forbidTools? | P0 |
| EV2 | Builtin cases e.g. “where is allowUnfree?”, “list specialized modules” | P0 |
| EV3 | `ncc ai eval run` → pass/fail report | P0 |
| EV4 | Knowledge invariants (index files exist, registries parse) | P0 |
| EV5 | Optional live LLM mode vs recorded fixtures | P1 |
| EV6 | CI job wiring (optional flake check) | P2 |

## Acceptance criteria

- [ ] Fixture mode fails if expected tool not called.
- [ ] Knowledge invariant fails on deleted registry file.

## Test plan

- Self-host: broken fixture → non-zero exit.
