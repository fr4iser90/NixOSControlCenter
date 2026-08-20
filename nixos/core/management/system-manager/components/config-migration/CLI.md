# CLI — config-migration

> SSOT: [STANDARDS](../../../cli-formatter/doc/STANDARDS.md) · [COPY](../../../cli-formatter/doc/COPY.md)

**Status:** `partial`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc-config-check` / `ncc system …` | Validate (+ migrate unless dry-run) | `--dry-run` | dry-run: no |
| `ncc-migrate-config` | Schema / platform heal | no | yes |
| `ncc-config-layout` | Detect / convert monolith ↔ split | convert writes | yes for convert |
| `ncc-cleanup-legacy-configs` | Legacy `configs/` rescue | no | yes |

## Self-audit

- [x] `formatter = getModuleApi "cli-formatter"` in check / migration / validator / layout / legacy-cleanup
- [x] No local colors / `echo -e` / ANSI in migration scripts
- [ ] Verbose detail gated with `-v` (partially present)
- [ ] `longHelp` matches COPY tone
- [x] Dry-run documented (`ncc-config-check --dry-run`)
- [ ] README links here

## Notes

Also registered under `ncc system migrate-config` / `config-layout`. See system-manager CLI.md for update flow.
