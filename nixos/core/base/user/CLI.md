# CLI — user

> SSOT: [STANDARDS](../../management/cli-formatter/doc/STANDARDS.md) · [COPY](../../management/cli-formatter/doc/COPY.md)

**Status:** `partial`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc user` | Help / `--gui` / `--tui` | N/A | no |
| `ncc user list\|show\|whoami` | Account inventory | N/A | no |
| `ncc user create\|set\|delete` | Account mutations via `ncc-priv` | no | via pkexec/sudo |

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in `scripts/ncc-user.nix`
- [x] Error / usage status via `ui.messages`
- [ ] Verbose detail gated with `-v`
- [ ] `longHelp` matches COPY tone
- [x] Dry-run documented or N/A
- [ ] README links here

## Notes

- List/show/whoami `key=value` / `--json` stay machine-plain.
- **Out of scope:** `home-manager/shellInit/{bash,zsh}Init.nix` PS1 / `echo -e` for `path` alias — user shell chrome, not NCC CLI.
