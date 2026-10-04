# CLI — hyprland

> SSOT: [STANDARDS](../../management/cli-formatter/doc/standards.md) · [COPY](../../management/cli-formatter/doc/copy.md)

**Status:** `partial`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc hyprland` | Help / `--gui` | N/A | no |
| `ncc hyprland rice list \| info <id>` | Browse Hall of Fame rices | N/A | no |
| `ncc hyprland wallpaper list` | Catalog wallpapers | N/A | no |
| `ncc hyprland status` | Module settings (`key=value`) | N/A | no |
| `ncc hyprland set …` | Write rice/wallpaper to systemConfig | yes where supported | yes |
| `ncc hyprland rice install <id>` | Fetch collection + patch flake | — | yes |
| `ncc hyprland rice validate <id>` | Hard validation gate before apply | N/A | no |
| `ncc hyprland rice verify` | Live config verify before login | N/A | no |

## Self-audit

- [ ] Formatter skeleton on mutating paths (`set` / `install`)
- [x] `longHelp` covers main entry points
- [x] README / usage link here
- [ ] Nested `NCC_CLI_NESTED` audit complete

## Notes

Hall of Fame gallery ≠ apply store (`NCC-Hyperland-Collection`). See [usage.md](./usage.md).
