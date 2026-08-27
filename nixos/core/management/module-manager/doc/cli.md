# CLI — module-manager

> SSOT: [STANDARDS](../cli-formatter/doc/standards.md) · [COPY](../cli-formatter/doc/copy.md)

**Status:** `compliant`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc modules list` | Discover + list modules | N/A (`--json` machine) | no |
| `ncc modules show NAME` | Module details | N/A | no |
| `ncc modules enable\|disable NAME` | Toggle in systemConfig | no | yes |
| `ncc modules migrate` | Named plans + orphan cleanup | `--dry-run` | yes (except dry-run) |
| `ncc modules --tui` | Modules TUI | N/A | yes |

## Output contract

- Normal: header → loading → facts → success/error → `Next:` (skip header/next when `NCC_CLI_NESTED=1`)
- migrate dry-run: dry banner + no writes
- `--json` on list: stdout JSON only

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in `commands.nix` + migrate runner
- [x] list / show / enable|disable / migrate follow §3 skeleton
- [x] Nested `NCC_CLI_NESTED=1` respected
- [x] Dry-run on migrate documented
- [ ] TUI (BubbleTea / Gum) — **out of scope for compliant**; start/load/error/success on Gum path use formatter
- [x] README links here

## Notes

Never touches `custom/` or `systemConfig/users/`. Compliant covers main `ncc modules` CLI verbs only.
