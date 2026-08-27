# CLI — hardware

> SSOT: [STANDARDS](../../management/cli-formatter/doc/standards.md) · [COPY](../../management/cli-formatter/doc/copy.md)

**Status:** `compliant`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc hardware` | Help / `--gui` | N/A | no |
| `ncc hardware status [--json] [-v]` | Configured vs detected inventory | N/A | no |
| `ncc hardware set autoDetect=…` | Toggle `enableChecks` | yes (`--dry-run`) | yes (skipped on dry-run) |

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in `scripts/ncc-hardware.nix`
- [x] Skeleton on status/set: header → dry banner → loading/facts → result → Next
- [x] Honor `NCC_CLI_NESTED`
- [x] `-v` gates probe details / paths
- [x] No private ANSI
- [x] `longHelp` matches COPY tone
- [x] README links here

## Notes

Human status uses `ui.tables` + messages. `--json` stays raw (no chrome).
