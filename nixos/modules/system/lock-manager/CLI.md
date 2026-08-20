# CLI — lock-manager

> SSOT: [STANDARDS](../../../core/management/cli-formatter/doc/STANDARDS.md) · [COPY](../../../core/management/cli-formatter/doc/COPY.md)

**Status:** `partial`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc lock` | Snapshot / restore / GitHub fetch | `--dry-run` (restore) | varies |

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in commands, collectors, handlers
- [x] Status emoji echoes replaced with `ui.messages.*` (JSON snapshot output stays raw)
- [ ] Verbose detail gated with `-v`
- [ ] `longHelp` matches COPY tone
- [x] Dry-run documented (restore)
- [ ] README links here

## Notes

Handlers/collectors take `ui` from callers. Option descriptions may still contain warning glyphs (not CLI status).
