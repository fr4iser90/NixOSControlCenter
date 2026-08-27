# UI matrix (CLI / TUI / GUI)

Heuristic from the tree (`commands.nix`, `ui/gui/page.py`, `ui/tui/`).  
Update when you add a surface — do not leave this stale for months.

| Module | CLI | TUI | GUI | Notes |
|--------|:---:|:---:|:---:|-------|
| **core/base** | | | | |
| audio | ✓ | — | — | |
| boot | ✓ | — | — | |
| desktop | ✓ | ✓ | ✓ | |
| hardware | ✓ | — | ✓ | |
| localization | ✓ | — | — | |
| network | ✓ | ✓ | ✓ | |
| packages | ✓ | ~ | ✓ | tui dir may be thin |
| user | ✓ | ✓ | ✓ | |
| **core/management** | | | | |
| cli-formatter | — | — | — | library |
| cli-registry | ✓ | ~ | — | registration hub |
| gui-engine | — | — | — | shared Qt kit |
| install-wizard | ✓ | — | ✓ | also `nix-shell` bootstrap |
| module-manager | ✓ | ✓ | ✓ | |
| nixos-control-center | ✓ | — | — | `ncc` root |
| system-manager | ✓ | ✓ | ✓ | update / checks |
| tui-engine | — | — | — | shared TUI kit |
| **modules/infrastructure** | | | | |
| bootentry-manager | ✓ | — | — | |
| stack-manager | ✓ | ✓ | ✓ | was homelab-manager |
| vm | ✓ | ✓ | ✓ | |
| **modules/security** | | | | |
| ssh-manager | ✓ | ✓ | ~ | host + client; GUI partial |
| remote-assist-manager | — | — | — | **docs only** |
| **modules/system** | | | | |
| lock-manager | ✓ | ✓ | ✓ | |
| **modules/specialized** | | | | |
| ai-workspace | — | — | — | little/no CLI surface |
| chronicle | ✓ | — | ~ | web bits possible |
| ncc-assistant | ✓ | — | ✓ | |
| nixify | ✓ | — | — | + web-service / iso-builder |

Legend: `✓` present · `~` partial / empty stub · `—` none

## GUI design

- Page scaffold: `nixos/core/management/gui-engine/doc/PAGE-TEMPLATE.md`
- Design / perf: `gui-engine/doc/GUI-DESIGN.md`, `PERFORMANCE.md`

## TUI notes

Longer Bubble Tea drafts live under [`tui/`](../tui/). Paths in those guides may still say `homelab-manager` or old layouts — prefer this matrix + real module trees.
