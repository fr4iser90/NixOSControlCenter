# CLI — desktop

> SSOT: [STANDARDS](../../management/cli-formatter/doc/standards.md) · [COPY](../../management/cli-formatter/doc/copy.md)

**Status:** `compliant`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc desktop` | Help / `--gui` / `--tui` | N/A | no |
| `ncc desktop status` | Current settings (`key=value`) | N/A | no |
| `ncc desktop set …` | Write desktop settings (+ optional `--rebuild`) | yes (`--dry-run`) | yes (skipped on dry-run) |

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in `scripts/desktop-set.nix`
- [x] Skeleton: header → dry banner → loading/facts → work → result → Next
- [x] Honor `NCC_CLI_NESTED`
- [x] `--verbose` gates paths/layout
- [x] No local colors / `echo -e` / ANSI
- [x] `longHelp` matches COPY tone
- [x] README links here

## Notes

`status` stays machine-friendly `key=value`. Mutating `set` owns the UX skeleton.
