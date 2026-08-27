# CLI — ncc-assistant

> SSOT: [STANDARDS](../../../core/management/cli-formatter/doc/standards.md) · [COPY](../../../core/management/cli-formatter/doc/copy.md)

**Status:** `compliant`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc ai` | GUI / chat / MCP / agent / tools (Nix wrapper → Python) | agent `--dry-run` | no |
| `ncc-assistant-config` | Read/write/validate module config fragments | N/A | write: elevates |

## Output contract

- **Nix entry** (`ncc-assistant` / `ncc ai`): header → loading → (Python body) → success/error → `Next:` for short verbs; interactive (`gui` / `chat` / `mcp` / `tray`) hand off after header+loading
- **Config helper**: header → loading → result → `Next:`
- `NCC_CLI_NESTED=1` skips header / next
- **Python** (`cli.py` / `chat.py`): secondary — status via `cli_print` (`info:` / `ok:` / `error:`); JSON/tables stay raw `print`

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in schedules + package config helper + wrapper
- [x] Nix wrapper + `ncc-assistant-config` follow §3 skeleton
- [x] Schedule skip / probe loading via `ui.messages`
- [x] Dry-run documented (agent)
- [x] Python CLI tone aligned (`cli_print.print_info` / `print_ok` / `print_err`; plain text)
- [x] README links here

## Notes

Compliant = Nix-facing `ncc ai` / `ncc-assistant-config` skeleton. Python agent/chat/tools remain a plain secondary surface behind the wrapper (same pattern as nixify standalone helpers).
