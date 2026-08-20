# CLI — ncc-assistant

> SSOT: [STANDARDS](../../../core/management/cli-formatter/doc/STANDARDS.md) · [COPY](../../../core/management/cli-formatter/doc/COPY.md)

**Status:** `partial`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc ai` | GUI / chat / MCP / agent / tools | agent `--dry-run` | no |
| `ncc-assistant-config` | Read/write/validate module config fragments | N/A | write: elevates |

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in schedules + package config helper errors
- [x] Schedule skip / probe loading via `ui.messages`
- [ ] Verbose detail gated with `-v`
- [ ] `longHelp` matches COPY tone
- [x] Dry-run documented (agent)
- [ ] README links here

## Notes

Python GUI button glyphs (`✓`) and transcript formatters are GUI/app surfaces, not NCC shell CLI status. Machine `valid` from config-helper stays plain.
