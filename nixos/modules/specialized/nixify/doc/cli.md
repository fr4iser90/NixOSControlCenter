# CLI — nixify

> SSOT: [STANDARDS](../../../core/management/cli-formatter/doc/standards.md) · [COPY](../../../core/management/cli-formatter/doc/copy.md)

**Status:** `compliant`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc nixify` | Service + ISO build | N/A (no `/etc/nixos` writes; ISO builds locally) | service/ISO vary |

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in `commands.nix`
- [x] Main `ncc nixify` flows: header → loading → result → `Next:` (honors `NCC_CLI_NESTED=1`)
- [x] ISO debug dump gated behind `-v` / `--verbose`
- [x] Standalone helpers plain status (no private ANSI / emoji): `iso-builder/validate-and-build.sh`, snapshot + web-service scan scripts (`.sh` / `.ps1`)
- [x] README links here

## Notes

Standalone bash/PowerShell helpers stay outside the `ncc nixify` formatter path (no `getModuleApi`); they use plain text status only.
