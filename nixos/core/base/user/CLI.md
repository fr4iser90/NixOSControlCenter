# CLI — user

> SSOT: [STANDARDS](../../management/cli-formatter/doc/STANDARDS.md) · [COPY](../../management/cli-formatter/doc/COPY.md)

**Status:** `compliant`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc user` | Help / `--gui` / `--tui` | N/A | no |
| `ncc user list\|show\|whoami` | Account inventory | N/A | no |
| `ncc user create\|set\|delete` | Account mutations via `ncc-priv` | yes (`--dry-run`) | via pkexec/sudo (skipped on dry-run) |

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in `scripts/ncc-user.nix`
- [x] Header (skipped when `NCC_CLI_NESTED=1`)
- [x] `--dry-run` on create/set/delete: banner + intended action, no `ncc-priv` write, Next
- [x] Loading / facts / success|error / Next (nested-aware)
- [x] No private ANSI for user status
- [x] Verbose detail gated with `-v` where applicable (short / machine surfaces OK)
- [x] `longHelp` matches COPY tone
- [x] README links here

## Notes

- List/show/whoami `key=value` / `--json` stay machine-plain under formatter chrome.
- **Out of scope:** `home-manager/shellInit/{bash,zsh}Init.nix` PS1 — user shell chrome, not NCC CLI.
