# CLI — vm

> SSOT: [STANDARDS](../../../core/management/cli-formatter/doc/STANDARDS.md) · [COPY](../../../core/management/cli-formatter/doc/COPY.md)

**Status:** `compliant`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc vm status\|list` | Libvirt status / test distros | N/A | group kvm/libvirtd |
| `ncc vm start\|stop\|destroy NAME` | Domain lifecycle | no | libvirt ACL |
| `ncc vm domains` | Machine `name=state` lines | N/A | libvirt ACL |
| `ncc vm test run\|reset <distro>` | Test VM helpers | no | group kvm |
| `ncc vm --tui` | TUI | N/A | varies |

## Output contract

- status / list / start / stop / destroy / test wrappers: header → loading → result → `Next:`
- `domains` + port/ISO path stdout: raw machine output (intentional)
- `NCC_CLI_NESTED=1` skips header / next

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in `commands.nix`
- [x] Main `ncc vm` verbs follow §3 skeleton
- [x] `lib/vm.nix` user-facing status plain text (no emoji)
- [ ] TUI — out of scope for compliant
- [x] README links here

## Notes

Compliant = `commands.nix` entry skeleton. `lib/vm.nix` test-runner status is plain text under delegated `test run`.
