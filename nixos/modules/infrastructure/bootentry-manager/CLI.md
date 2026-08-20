# CLI — bootentry-manager

> SSOT: [STANDARDS](../../../core/management/cli-formatter/doc/STANDARDS.md) · [COPY](../../../core/management/cli-formatter/doc/COPY.md)

**Status:** `partial`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `list-boot-entries` | Dump `/boot/loader/entries` confs | N/A | typically yes |
| `rename-boot-entry` | Rename generation title | no | yes |
| `reset-boot-entry` | Reset generation title | no | yes |

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in `lib/common.nix` (permission error)
- [x] No private ANSI / emoji status chrome
- [ ] Verbose detail gated with `-v`
- [ ] `longHelp` matches COPY tone
- [x] Dry-run documented or N/A
- [ ] README links here

## Notes

Mostly activation sync + thin shell binaries that cat/sed boot entries (raw conf output intentional). No `ncc …` registry domain yet.
