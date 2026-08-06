# Phase 0 — Status quo

**Status:** done (baseline for roadmap)  
**Parent:** [ROADMAP.md](../ROADMAP.md)

## What exists today

Module: `nixos/modules/specialized/ncc-assistant/`

| Area | Location | Behavior |
|------|----------|----------|
| Nix options | `options.nix`, `template-config.nix` | `enable`, `endpoint`, `api`, `model`, guards, optional key file |
| Package | `package.nix` | `ncc-assistant`, `ncc-assistant-mcp`, desktop entry, PySide6 + httpx + mcp |
| CLI | `python/ncc_assistant/cli.py` | `gui` (default), `chat`/`cli`, `mcp`, `tool`, `tools` |
| GUI | `gui.py` | Qt chat, sessions, streaming, stop, model picker, vision Img, confirms |
| Session | `session.py` | tool loop, stream events, cancel, persist |
| History | `history.py` | `~/.config/ncc-assistant/sessions/` |
| Auth | `auth.py` | probe, prompt, credentials cache |
| LLM | `llm.py` | OpenAI-compatible (+ Anthropic), stream, `/models`, vision heuristics |
| Tools | `runtime.py` | fixed `TOOL_DEFINITIONS` + `ToolRuntime.call` |
| MCP server | `mcp_server.py` | exposes built-ins over stdio for Cursor/Claude Code |
| Docs | `USAGE.md` | operator guide |

## Built-in tools

- `list_modules`, `read_module_config`, `search_knowledge`, `explain_path`
- `propose_config_patch`, `apply_module_config`, `validate_config`, `apply_system`

Guards: `allowWrite` / `mcpAllowWrite` / `allowRebuild`; GUI confirm hook for write/rebuild.

## Gaps this roadmap closes

- Tools are **hardcoded** — no user/MCP extension path for *inbound* tools.
- No **agent** with goal/budget separate from chat.
- No **job** artifacts for unattended/on-demand runs.
- No **schedules** / timers.
- GUI is **chat-centric** — no Tools / Agent / Jobs / Schedules sections.

## Do not regress

When building later phases:

- Keep MCP *server* working for external IDEs.
- Keep flake-safe packaging (no paths outside `nixos/` flake root).
- Keep credential model (no secrets in monolith config).
