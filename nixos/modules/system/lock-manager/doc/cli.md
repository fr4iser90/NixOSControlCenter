# CLI — lock-manager

> SSOT: [STANDARDS](../../../core/management/cli-formatter/doc/standards.md) · [COPY](../../../core/management/cli-formatter/doc/copy.md)

**Status:** `compliant`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc lock discover` | Scan → snapshot (+ encrypt/upload) | no | no |
| `ncc lock restore` | Restore from snapshot | `--dry-run` | no |
| `ncc lock fetch` | List/download GitHub snapshots | N/A | no |
| `ncc lock restore-from-github` | Fetch + restore | via restore | no |
| `ncc lock --tui` | TUI | N/A | no |

## Output contract

- discover / restore / fetch / restore-from-github: header → loading → facts → result → `Next:`
- restore dry-run: dry banner + no writes
- Nested restore under restore-from-github uses `NCC_CLI_NESTED=1`

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in commands + restore / fetch handlers
- [x] discover / restore / fetch / restore-from-github follow §3 skeleton
- [x] Dry-run on restore
- [ ] TUI — out of scope for compliant
- [x] README links here

## Notes

JSON snapshot payload stays raw. Compliant = main snapshot/restore `ncc lock` verbs.
