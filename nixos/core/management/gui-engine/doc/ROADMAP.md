# NCC GUI Engine — domain pages roadmap

## Done

| Domain | Page | Notes |
|--------|------|--------|
| packages | custom | catalog + modules |
| system | custom | update / rebuild actions |
| network | custom | wifi form |
| lock | custom | snapshot / restore |
| ai | custom (+ assistant app) | chat / tools / jobs |
| modules | `ncc-modules-gui` | separate binary |
| **ssh** | custom | client list, **embedded PTY**, server tab |
| **homelab** | custom | status / stacks + **remote Target** |
| **vm** | custom | domains list + start/stop/destroy + Target |
| **desktop** | custom | settings view (`ncc desktop status`) + Target |
| **user** | custom | user list (`ncc user list`) + Target |
| chronicle | own app GUI | catalog stub |

## Remote target

Homelab / VM / Desktop / User pages share `TargetBar` + `ncc_gui.remote`:

- **This machine** → `ncc …`
- **Remote SSH…** → `ssh user@host -- ncc …` (BatchMode)

Use case: Gaming laptop GUI → server with same modules, other `systemConfig`.
Also: `NCC_TARGET_HOST=user@host`.

## Next (optional)

- [ ] Desktop / User: in-GUI edit of systemConfig + rebuild confirm
- [ ] Homelab: deploy/remove stack verbs (today TUI-only)
- [ ] SSH: richer VT100 (QTermWidget) if we package bindings
- [ ] Chronicle: embed or deep-link from catalog page
- [ ] VM: run/reset test distro from GUI
