# CLI — ssh-manager client

> SSOT: [STANDARDS](../../../../core/management/cli-formatter/doc/STANDARDS.md) · [COPY](../../../../core/management/cli-formatter/doc/COPY.md)

**Status:** `partial`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc ssh client` | Interactive connection manager | N/A | no |
| `ncc ssh client --tui\|--gui` | TUI / domain GUI | N/A | no |
| `ncc ssh client list\|add\|edit\|delete\|connect` | Direct actions | N/A | no |

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in main / keys / remote-hosts / handlers
- [x] `connection-preview.nix` human chrome → `ui.text` / `ui.tables` / `ui.badges` / `ui.messages`
- [x] No private ANSI / emoji status (`★`/`✓`/`✗` / `echo -e`) in preview
- [ ] Verbose detail gated with `-v`
- [ ] `longHelp` matches COPY tone
- [x] Dry-run documented or N/A
- [ ] README links here

## Notes

Preview cache stores `ok`/`fail` + details (not colored strings). TUI Go code may still use Lipgloss / comment glyphs — out of NCC shell CLI formatter scope.
