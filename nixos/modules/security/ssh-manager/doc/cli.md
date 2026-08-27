# CLI — ssh-manager

> SSOT: [STANDARDS](../../../core/management/cli-formatter/doc/standards.md) · [COPY](../../../core/management/cli-formatter/doc/copy.md)

**Status:** `compliant`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc ssh` | Help / `--gui` / client router | N/A | no |
| `ncc ssh status` | Daemon / auth mode summary | N/A | no |
| `ncc ssh lockdown` | Disable password auth after checks | `--dry-run` | yes |
| `ncc ssh grant-access USER …` | Timed password reopen | no | yes |
| `ncc ssh temp-open\|force-open` | Timed reopen variants | no | yes |
| `ncc ssh request-access USER REASON [DUR]` | Submit access request (`workflow.enable`) | no | yes |
| `ncc ssh approve-request ID [DUR]` | Approve pending request | no | yes |
| `ncc ssh deny-request ID REASON` | Deny pending request | no | yes |
| `ncc ssh list-requests [STATUS]` | List / filter requests | N/A | no |
| `ncc ssh cleanup-requests [DAYS]` | Prune old request files | no | no |
| `ncc ssh monitor` | Follow sshd journal | N/A | no |

Workflow verbs load only when `workflow.enable = true` (with server `enable`).

## Output contract

- status / lockdown / grant-access / workflow scripts: header → loading → facts → result → `Next:`
- lockdown dry-run: dry banner + no writes under `/etc/nixos`
- `NCC_CLI_NESTED=1` skips header / dry banner / next

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in commands + lockdown / grant-access / workflow scripts
- [x] status / lockdown / grant-access follow §3 skeleton
- [x] Dry-run on lockdown
- [x] Workflow scripts (`request-access` / `approve-request` / `deny-request` / `list-requests` / `cleanup-requests` / `monitor`) wired when `workflow.enable`
- [x] README links here

## Notes

Compliant covers main server-side `ncc ssh` verbs (status, lockdown, grant-access) and optional workflow.
Client verbs / Go TUI: see [client/doc/cli.md](./client/doc/cli.md).
