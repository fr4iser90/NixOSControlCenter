# CLI — bootentry-manager

> SSOT: [STANDARDS](../../../core/management/cli-formatter/doc/STANDARDS.md) · [COPY](../../../core/management/cli-formatter/doc/COPY.md)

**Status:** `compliant`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc bootentry` | Help | N/A | no |
| `ncc bootentry list` | Dump systemd-boot / GRUB generation confs (rEFInd: stub error) | N/A | root/wheel |
| `ncc bootentry rename GEN TITLE` | Rename generation title (rEFInd: stub error) | no | root/wheel |
| `ncc bootentry reset GEN` | Reset generation title (rEFInd: stub error) | no | root/wheel |

Bare package binaries (`list-boot-entries`, `rename-boot-entry`, …) remain installed for compatibility; prefer `ncc bootentry …`.

## Output contract

- Handler binaries (via `ncc bootentry …`): header → loading → conf dump or mutate → success/warning → `Next:`
- Raw `.conf` / `.cfg` body stays uncolored (intentional)
- `NCC_CLI_NESTED=1` skips header / next

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` via handlers + `lib/common.nix` + `commands.nix`
- [x] list / rename / reset scripts follow §3 skeleton
- [x] Registered under `ncc bootentry` via `cli-registry.registerCommandsFor`
- [x] Dry-run N/A (documented)
- [x] `refind.nix` thin stub wired (list/rename/reset error with `Next:`; no real mutation yet)
- [x] README links here

## Notes

Compliant = `ncc bootentry` domain + handler skeleton. Provider is systemd-boot, GRUB, or rEFInd (stub) based on the host bootloader.
