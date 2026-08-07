# Phase 25 — Compact UI for tool traces

Status: **done** (see ROADMAP.md)

**Status:** planned (backlog)  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 5 UI shell  
**Related:** [05-ui-integration.md](./05-ui-integration.md), [16-budgets-visible.md](./16-budgets-visible.md)

## Problem

Agent runs with many tool calls flood the chat with large bubbles. Need denser
trace view without losing access to details.

## Goals

1. Compact/dense theme for tool traces (collapsible rows).
2. Toggle Comfortable vs Compact in Agent (and optional Chat).
3. Click row → expand args/result; keep assistant markdown readable.

## Features

| ID | Feature | Priority |
|----|---------|----------|
| UI1 | Collapsible tool rows: `tool · name · 120ms · ok` | P0 |
| UI2 | Density toggle persisted in user settings | P0 |
| UI3 | Virtualize long traces (performance) | P1 |
| UI4 | Filter: tools only / assistant only | P2 |
| UI5 | Color-blind safe status icons (not color-only) | P1 |

## Acceptance criteria

- [ ] 50 tool calls remain scrollable/usable in compact mode.
- [ ] Expanding a row shows full result text.

## Test plan

- Manual density toggle; generate long fake event list.
