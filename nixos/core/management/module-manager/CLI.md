# CLI — module-manager

> SSOT: [STANDARDS](../cli-formatter/doc/STANDARDS.md) · [COPY](../cli-formatter/doc/COPY.md)

**Status:** `partial`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc modules migrate` | Named plans (rename/merge) + orphan cleanup | `--dry-run` | yes (except dry-run) |
| `ncc modules …` (TUI / discovery) | Module UI / helpers | N/A / varies | varies |

## How migrate should look

```text
Checking module config migrations…
Scanning module migration plans…
Plan stack-manager-rename-v1: rename … → …
Would rename (dry-run) — no changes written   # or success when applying
… orphans …
Dry-run: N plan(s) would run                  # or complete
```

`-v`: layout, JSON previews, full paths.

## Self-audit

- [x] `ncc_backup_config_file` (no `BACKUP_ROOT` unbound under `set -u`)
- [x] Plans use `ui.messages.*`; JSON preview behind `-v`
- [ ] TUI / other scripts full COPY pass
- [ ] README links here

## Notes

Never touches `custom/` or `systemConfig/users/`.
