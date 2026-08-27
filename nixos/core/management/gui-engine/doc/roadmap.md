# NCC GUI Engine — domain pages roadmap

**Design SSOT:** [gui-design.md](./gui-design.md) — Header → Content → Activity → Footer Actions.  
**Perf / cache SSOT:** [performance.md](./performance.md) — UI thread, Chrome+Document, catalogs vs live state.

## Architecture

Rich pages live **in each module** (`ui/gui/page.py` + `registerGuiPage`).  
`gui-engine` provides the **kit** (`DomainPage` / scaffold), shell, Target, theme, generic fallback.

## Done

| Domain | Page location | Notes |
|--------|---------------|--------|
| **kit** | `gui-engine` → `ncc_gui.scaffold.DomainPage` | Header → Content → Activity → Footer Actions |
| modules | `module-manager/ui/gui` | list / show / enable / disable |
| packages | `core/base/packages/ui/gui` | catalog + modules |
| system | `system-manager/ui/gui` | local/remote/channels sync + rebuild |
| network | `core/base/network/ui/gui` | wifi form |
| lock | `lock-manager/ui/gui` | snapshot / restore |
| ai | `ncc-assistant/ui/gui` | chat / tools / jobs (+ DomainPage fallback) |
| ssh | `ssh-manager/ui/gui` | client list, embedded PTY; Target bar uses same `~/.creds` |
| homelab | `homelab-manager/ui/gui` | status / stacks |
| vm | `vm/ui/gui` | domains + start/stop |
| desktop | `desktop/ui/gui` | editable + rebuild |
| user | `user/ui/gui` | list / detail |
| chronicle | own app GUI | catalog stub |

All listed rich pages subclass **`DomainPage`** (or embed assistant; fallback uses kit).

## Global Target (fleet)

Root NCC GUI has a **Target** bar = *which machine you Connect to*
(This machine + hosts from `ncc ssh client` / `~/.creds`).

- **Select** a host = candidate only (not yet remote NCC)
- **Connect** = SSH probe (OS / arch / `ncc` / `configVersion`) → session gate
- **Disconnect** = back to this machine
- Persists last Connect to `~/.config/ncc/active-target`; live session uses `NCC_TARGET_HOST`
- Gate banner: **blocked** | **needs_install** → Install | **needs_update** → System | **ready**
- Most domains follow connected Target (`ssh user@host -- ncc …`); elevated: `ssh … sudo -n ncc …`
- **Always local:** `ssh` (client list / connections from this PC)
- While gated remote: sidebar limited (ssh + install/system as needed)
- When **ready**: sidebar = domains enabled on that host

Clients: `ncc ssh client list|add|…`. Session target: Target bar only (no separate hosts module).

## Next (optional)

- [ ] Remote access policy (view vs edit)
- [ ] Dedicated SystemConfig / Hardware browser (read-only)
- [ ] Desktop / User: in-GUI edit of systemConfig + rebuild confirm
- [ ] Homelab: deploy/remove stack verbs (today TUI-only)
- [ ] SSH: richer VT100 (QTermWidget) if we package bindings
- [ ] Chronicle: embed or deep-link from catalog page
- [ ] VM: run/reset test distro from GUI
- [ ] Richer remote catalog JSON (`ncc domains --json`) instead of parsing `ncc help`
