# CLI — hardware

> SSOT: [STANDARDS](../../management/cli-formatter/doc/STANDARDS.md) · [COPY](../../management/cli-formatter/doc/COPY.md)

**Status:** `partial`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc hardware` | Help / `--gui` | N/A | no |
| `ncc hardware status [--json]` | Configured vs detected inventory | N/A | no |
| `ncc hardware set autoDetect=…` | Toggle `enableChecks` | no | yes |

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in `scripts/ncc-hardware.nix`
- [x] Set / error status via `ui.messages` (no private ANSI)
- [ ] Verbose detail gated with `-v`
- [ ] `longHelp` matches COPY tone
- [x] Dry-run documented or N/A
- [ ] README links here

## Notes

Human status / errors use formatter. Plain `key=value` and `--json` status dumps stay uncolored.
