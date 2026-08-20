# CLI — desktop

> SSOT: [STANDARDS](../../management/cli-formatter/doc/STANDARDS.md) · [COPY](../../management/cli-formatter/doc/COPY.md)

**Status:** `partial`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc desktop` | Help / `--gui` / `--tui` | N/A | no |
| `ncc desktop status` | Current settings (`key=value`) | N/A | no |
| `ncc desktop set …` | Write desktop settings (+ optional `--rebuild`) | no | yes |

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in `scripts/desktop-set.nix`
- [x] No local colors / `echo -e` / ANSI in set script
- [ ] Verbose detail gated with `-v`
- [ ] `longHelp` matches COPY tone
- [x] Dry-run documented or N/A
- [ ] README links here

## Notes

`status` stays machine-friendly `key=value`. Mutating `set` uses `ui.messages` / `ui.tables`.
