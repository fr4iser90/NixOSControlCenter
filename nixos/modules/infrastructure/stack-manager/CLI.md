# CLI — stack-manager

> SSOT: [STANDARDS](../../../core/management/cli-formatter/doc/STANDARDS.md) · [COPY](../../../core/management/cli-formatter/doc/COPY.md)

**Status:** `partial`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc stacks` | Stacks domain entry | N/A | varies |
| `ncc stacks fetch` | Fetch catalog (`ncc-stacks-fetch`) | no | virt user |
| `ncc stacks init` | Init stacks (`ncc-stacks-init`) | no | virt user |

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in handlers (`stacks-fetch` / `stacks-create`) and TUI helpers
- [ ] No local colors / `echo -e` / ANSI everywhere (e.g. `stacks-utils` minimize still plain)
- [ ] Verbose detail gated with `-v`
- [ ] `longHelp` matches COPY tone
- [ ] Dry-run documented or N/A
- [ ] README links here

## Notes

- Fetch/init status lines use `ui.messages.{error,warning,success,loading}`; plain `echo` kept for raw facts (repo/dest).
- TUI `helpers.nix` fixed to `getModuleApi "cli-formatter"` (was broken `config.${builtins.getModuleApi …}`).
