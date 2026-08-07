# Phase 21 — Export registry (MCP + OpenAPI)

Status: **done** (see ROADMAP.md)

**Status:** planned (backlog)  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 1  
**Related:** [19-mcp-marketplace.md](./19-mcp-marketplace.md)

## Problem

External clients may want the same tool surface without embedding Python.
Today only FastMCP stdio exports builtins.

## Goals

1. Export **enabled registry** (builtin+shell+mcp-reexport policy TBD) via MCP.
2. Optional OpenAPI/HTTP endpoint for automation (localhost, auth token).
3. Document security: default bind localhost; writes still guarded.

## Features

| ID | Feature | Priority |
|----|---------|----------|
| EX1 | MCP server dynamically registers enabled tools | P0 |
| EX2 | Flag whether to re-export nested MCP tools (default false) | P0 |
| EX3 | `ncc ai serve-openapi` localhost OpenAPI 3 + tool POST | P1 |
| EX4 | Token file auth for HTTP | P0 (if HTTP exists) |
| EX5 | GUI: copy MCP config snippet for Cursor | P1 |

## Acceptance criteria

- [ ] Disabled tools absent from MCP listTools.
- [ ] OpenAPI (if enabled) refuses remote bind without explicit opt-in.

## Test plan

- MCP listTools snapshot; HTTP 401 without token.
