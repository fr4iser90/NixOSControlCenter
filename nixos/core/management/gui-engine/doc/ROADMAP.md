# NCC GUI Engine — domain pages roadmap

## Architecture

Rich pages live **in each module** (`ui/gui/page.py` + `registerGuiPage`).  
`gui-engine` only provides shell / Target / theme / generic fallback.

## Done

| Domain | Page location | Notes |
|--------|---------------|--------|
| packages | `core/base/packages/ui/gui` | catalog + modules |
| system | `system-manager/ui/gui` | local/remote/channels sync + rebuild |
| network | `core/base/network/ui/gui` | wifi form |
| lock | `lock-manager/ui/gui` | snapshot / restore |
| ai | `ncc-assistant/ui/gui` | chat / tools / jobs |
| modules | `ncc-modules-gui` | separate binary |
| ssh | `ssh-client-manager/ui/gui` | client list, embedded PTY |
| hosts | `hosts/ui/gui` | fleet targets |
| homelab | `homelab-manager/ui/gui` | status / stacks |
| vm | `vm/ui/gui` | domains + start/stop |
| desktop | `desktop/ui/gui` | follows Target |
| user | `user/ui/gui` | follows Target |
| chronicle | own app GUI | catalog stub |

## Global Target (fleet)

Root NCC GUI has a **Target** bar = *which machine’s NCC you are using*
(This machine + hosts from `ncc ssh client` / `~/.creds`).

- Persists to `~/.config/ncc/active-target` and `NCC_TARGET_HOST`
- Most domains follow Target (`ssh user@host -- ncc …`)
- **Always local:** `hosts`, `ssh` (manage connections from this PC)
- **Sidebar:** only domains **enabled on the active target** (disabled = hidden)
- No custom sidebar editor — enable/disable via **Modules** on that host

CLI: `ncc hosts list|show|use|add|remove` and `ncc hosts --gui`.

## Next (optional)

- [ ] Remote access policy (view vs edit)
- [ ] Dedicated SystemConfig / Hardware browser (read-only)
- [ ] Desktop / User: in-GUI edit of systemConfig + rebuild confirm
- [ ] Homelab: deploy/remove stack verbs (today TUI-only)
- [ ] SSH: richer VT100 (QTermWidget) if we package bindings
- [ ] Chronicle: embed or deep-link from catalog page
- [ ] VM: run/reset test distro from GUI
- [ ] Richer remote catalog JSON (`ncc domains --json`) instead of parsing `ncc help`
