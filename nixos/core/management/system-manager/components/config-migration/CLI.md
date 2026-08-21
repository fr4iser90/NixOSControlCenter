# CLI — config-migration

> SSOT: [STANDARDS](../../../cli-formatter/doc/STANDARDS.md) · [COPY](../../../cli-formatter/doc/COPY.md)

**Status:** `compliant`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc-config-check` / `ncc system …` | Validate (+ migrate unless dry-run) | `--dry-run` | dry-run: no |
| `ncc-migrate-config` | Schema / platform heal | no | yes |
| `ncc-config-layout` | Detect / convert monolith ↔ split | convert writes | yes for convert |
| `ncc-cleanup-legacy-configs` | Legacy `configs/` rescue | no | yes |

## Self-audit

- [x] `formatter = getModuleApi "cli-formatter"` in check / migration / validator / layout / legacy-cleanup
- [x] `ncc-config-check` skeleton: header → dry banner → result → `Next:` (honors `NCC_CLI_NESTED=1`)
- [x] No local colors / `echo -e` / ANSI for user status (formatter messages)
- [x] Dry-run documented (`ncc-config-check --dry-run`)
- [x] Verbose detail gated with `-v` where applicable (short / machine surfaces OK)
- [x] README links here

## Notes

Also registered under `ncc system migrate-config` / `config-layout`. See system-manager CLI.md for update flow.

`migration.nix` raw `echo`/`printf` are for writing Nix fragments / piping jq — not status UX. Non-blocking for skeleton compliance.
