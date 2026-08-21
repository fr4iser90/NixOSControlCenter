# CLI — stack-manager

> SSOT: [STANDARDS](../../../core/management/cli-formatter/doc/STANDARDS.md) · [COPY](../../../core/management/cli-formatter/doc/COPY.md)

**Status:** `compliant`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc stacks status` | Docker / Swarm / config facts | N/A (`--json`) | no |
| `ncc stacks fetch` | Clone/update catalog | no (N/A) | virt user |
| `ncc stacks init` | Run catalog installer | no (N/A) | virt user |
| `ncc stacks ops\|swarm\|list-*` | Day-2 / list helpers | no | varies |
| `ncc stacks manager` | TUI | N/A | no |

## Output contract

- status / fetch / init: header → loading → facts → success/error → `Next:`
- Machine helpers (`list-containers` / ports / domains): pipe-delimited raw (intentional)
- Catalog scripts under `$HOME/…/docker-scripts` own chrome when delegated (`ops`)

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in commands + fetch/init handlers
- [x] status / fetch / init follow §3 skeleton + `NCC_CLI_NESTED`
- [x] Dry-run N/A for fetch/init (mutating catalog install; documented)
- [x] `stacks-utils` minimize uses `ui.messages`
- [ ] TUI (`homelab-tui-actions`) — out of scope for compliant
- [x] README links here

## Notes

Alias: `ncc homelab` → `ncc stacks`. Compliant = main entry commands (status/fetch/init).
