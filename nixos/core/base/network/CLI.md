# CLI — network

> SSOT: [STANDARDS](../../management/cli-formatter/doc/STANDARDS.md) · [COPY](../../management/cli-formatter/doc/COPY.md)

**Status:** `partial`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc network` | Help / `--gui` / `--tui` | N/A | no |
| `ncc network status [--json]` | Link summary (`key=value`) | N/A | no |
| `ncc network wifi …` | Scan / list / connect / forget / radio | no | connect/forget: yes |
| `ncc network ethernet …` | Status / disconnect / reconnect | no | mutate: yes |

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in wifi + ethernet routers
- [x] Human success/error/loading via `ui.messages` / section headers
- [ ] Verbose detail gated with `-v`
- [ ] `longHelp` matches COPY tone
- [x] Dry-run documented or N/A
- [ ] README links here

## Notes

`status` / `--json` and nmcli table dumps stay raw. WiFi list row details stay plain text under formatter section headers.
