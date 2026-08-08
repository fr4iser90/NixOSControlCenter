# NCC GUI Engine — domain pages roadmap

**Design SSOT:** [GUI-DESIGN.md](./GUI-DESIGN.md) — Header → Content → Actions → Activity.

## Architecture

Rich pages live **in each module** (`ui/gui/page.py` + `registerGuiPage`).  
`gui-engine` provides the **kit** (`DomainPage` / scaffold), shell, Target, theme, generic fallback.

## Done

| Domain | Page location | Notes |
|--------|---------------|--------|
| **kit** | `gui-engine` → `ncc_gui.scaffold.DomainPage` | Header → Content → Actions → Activity |
| packages | `core/base/packages/ui/gui` | catalog + modules |
| system | `system-manager/ui/gui` | local/remote/channels sync + rebuild |
| network | `core/base/network/ui/gui` | wifi form |
| lock | `lock-manager/ui/gui` | snapshot / restore |
| ai | `ncc-assistant/ui/gui` | chat / tools / jobs (+ DomainPage fallback) |
| modules | `ncc-modules-gui` | separate binary |
| ssh | `ssh-client-manager/ui/gui` | client list, embedded PTY |
| hosts | `hosts/ui/gui` | fleet targets |
| homelab | `homelab-manager/ui/gui` | status / stacks |
| vm | `vm/ui/gui` | domains + start/stop |
| desktop | `desktop/ui/gui` | editable + rebuild |
| user | `user/ui/gui` | list / detail |
| chronicle | own app GUI | catalog stub |

All listed rich pages subclass **`DomainPage`** (or embed assistant; fallback uses kit).

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
