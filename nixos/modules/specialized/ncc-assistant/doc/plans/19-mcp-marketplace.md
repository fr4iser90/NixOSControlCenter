# Phase 19 — Tool marketplace / MCP templates

Status: **done** (see ROADMAP.md)

**Status:** planned (backlog)  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 1 (MCP client + Tools UI)  
**Related:** [21-export-registry.md](./21-export-registry.md)

## Problem

Adding MCP servers by hand (command/args/env) is tedious. Users want curated
snippets: filesystem, git, browser, etc.

## Goals

1. Template catalog shipped with the module (JSON).
2. Tools UI: “Add from template” → fills form; user reviews paths/commands.
3. No silent network install of arbitrary binaries without confirmation.

## Features

| ID | Feature | Priority |
|----|---------|----------|
| MP1 | Catalog `templates/mcp/*.json` (name, description, command, args, risk) | P0 |
| MP2 | Templates: filesystem, git, fetch, browser (if packaged) | P0 |
| MP3 | GUI picker + path parameterization (e.g. allowed root dir) | P0 |
| MP4 | Risk badges (read / write / network) | P1 |
| MP5 | Optional “install hint” (nix shell / uvx) shown, not auto-run | P1 |
| MP6 | User can save custom template locally | P2 |

## Acceptance criteria

- [ ] Adding filesystem template creates enabled mcpServers entry (user or Nix snippet).
- [ ] Write-risk template warns before enable.

## Test plan

- Catalog load; parameter substitution unit tests.
