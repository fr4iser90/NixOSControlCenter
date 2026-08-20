# CLI — ssh-manager

> SSOT: [STANDARDS](../../../core/management/cli-formatter/doc/STANDARDS.md) · [COPY](../../../core/management/cli-formatter/doc/COPY.md)

**Status:** `partial`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc ssh` | Help / `--gui` / client router | N/A | no |
| `ncc ssh status` | Daemon / auth mode summary | N/A | no |
| `ncc ssh lockdown` | Disable password auth after checks | `--dry-run` | yes |
| `ncc ssh temp-open\|force-open\|grant-access` | Timed password reopen | no | yes |
| `ncc ssh request-access\|approve-request\|…` | Optional workflow | varies | varies |

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in commands + server scripts
- [x] Status / lockdown / grant use `ui.messages` / tables
- [x] `monitoring.nix` no longer uses `echo -e` for connection list filter
- [ ] Verbose detail gated with `-v`
- [ ] `longHelp` matches COPY tone
- [x] Dry-run documented (lockdown)
- [ ] README links here

## Notes

Client preview chrome lives under `client/` (see client/CLI.md). Template/options may still mention `✓` as fzf marker glyph (not CLI status).
