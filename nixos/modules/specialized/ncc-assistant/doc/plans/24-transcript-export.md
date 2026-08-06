# Phase 24 — Transcript export

**Status:** planned (backlog)  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 0 sessions, phase 3 jobs  
**Related:** [05-ui-integration.md](./05-ui-integration.md)

## Problem

Users want to paste agent/chat outcomes into GitHub issues or docs — currently
only raw session JSON.

## Goals

1. Export session or job transcript to Markdown and HTML.
2. Redact secrets; optionally omit huge tool payloads.
3. GUI: Export button; CLI: `ncc ai export`.

## Features

| ID | Feature | Priority |
|----|---------|----------|
| TE1 | Markdown export (roles, tools collapsed) | P0 |
| TE2 | HTML export (simple readable) | P1 |
| TE3 | Options: include tools full/summary, strip images | P0 |
| TE4 | Secret redaction pass | P0 |
| TE5 | Copy to clipboard + Save as… | P0 |
| TE6 | Export from Jobs detail | P1 |

## Acceptance criteria

- [ ] Export contains user+assistant turns in order.
- [ ] API keys in tool args do not appear in output.

## Test plan

- Fixture session → markdown snapshot; redaction cases.
