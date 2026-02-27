## TUI Layout Matrix (Current + Planned)

### Available Layouts (Go TUI)
- `full` (5 panels)
- `medium` (3 panels)
- `compact` (vertical stack)
- `ultra-compact` (single column)
- `emergency` (minimal)

### Layout Overrides (NCC_TUI_LAYOUT)
Modules may set a preferred layout via `buildDomainTui { layout = "medium"; }` which is exported to `NCC_TUI_LAYOUT`.

### Module Recommendations
| Module | Current UI | Recommended Layout | Notes |
|--------|------------|--------------------|-------|
| ssh-client-manager | FZF/CLI + TUI wrapper | `medium` | 2-panel-ish list + details preview |
| system-manager | TUI wrapper | `full` | Dashboard style |
| module-manager | Go TUI | `full` | 5-panel manager |
| lock-manager | TUI wrapper | `medium` or `full` | snapshots + stats |
| vm | TUI wrapper | `medium` | list + status |
| desktop | TUI wrapper | `medium` | list + details |
| user | TUI wrapper | `medium` | list + details |
| network | TUI wrapper | `medium` | list + details |
| packages | CLI stub | `compact` | package list |
| nixify | CLI | `compact`/`form` | wizard flow |
| chronicle | CLI | `compact`/`status` | sessions list |
| ssh-server-manager | CLI | `status` | status-only |
# UI-Matrix pro Modul (CLI / fzf / TUI / GUI / Web)

> Generiert aus Repo-Struktur (default.nix, commands/scripts, fzf-Vorkommen, ui/tui/gui/web-Verzeichnisse).

| Modul | CLI | fzf | TUI | GUI | Web | Struktur | Priorität |
|---|:--:|:--:|:--:|:--:|:--:|---|:--:|
| `nixos/core/base/audio` | ✅ | — | — | — | — | ⚠️ CLI commands only (no scripts/ dir) | Medium |
| `nixos/core/base/boot` | ✅ | — | — | — | — | ⚠️ CLI commands only (no scripts/ dir) | Medium |
| `nixos/core/base/desktop` | ✅ | — | ✅ | — | — | ⚠️ CLI commands only (no scripts/ dir) | Medium |
| `nixos/core/base/hardware` | ✅ | — | — | — | — | ⚠️ CLI commands only (no scripts/ dir) | Medium |
| `nixos/core/base/localization` | ✅ | — | — | — | — | ⚠️ CLI commands only (no scripts/ dir) | Medium |
| `nixos/core/base/network` | ✅ | — | ✅ | — | — | ⚠️ CLI commands only (no scripts/ dir) | Medium |
| `nixos/core/base/packages` | ✅ | ✅ | ✅ | — | — | ⚠️ CLI commands only (no scripts/ dir) | Medium |
| `nixos/core/base/user` | ✅ | ✅ | ✅ | — | — | ⚠️ CLI commands only (no scripts/ dir) | Medium |
| `nixos/core/management/cli-formatter` | — | ✅ | — | — | — | ✅ ok | Low |
| `nixos/core/management/cli-registry` | ✅ | ✅ | — | — | — | ✅ ok | Low |
| `nixos/core/management/module-manager` | ✅ | ✅ | ✅ | — | — | ✅ ok | Low |
| `nixos/core/management/nixos-control-center` | ✅ | — | ✅ | — | — | ⚠️ CLI commands only (no scripts/ dir) | Medium |
| `nixos/core/management/system-manager` | ✅ | — | ✅ | — | — | ✅ ok | Low |
| `nixos/core/management/tui-engine` | ✅ | — | — | — | — | ✅ ok | Low |
| `nixos/modules/infrastructure/bootentry-manager` | ✅ | — | — | — | — | ⚠️ CLI commands only (no scripts/ dir) | Medium |
| `nixos/modules/infrastructure/homelab-manager` | ✅ | ✅ | ✅ | — | — | ⚠️ CLI commands only (no scripts/ dir) | Medium |
| `nixos/modules/infrastructure/vm` | ✅ | — | ✅ | — | — | ⚠️ CLI commands only (no scripts/ dir) | Medium |
| `nixos/modules/security/ssh-client-manager` | ✅ | ✅ | ✅ | — | — | ✅ ok | Low |
| `nixos/modules/security/ssh-server-manager` | ✅ | — | — | — | — | ✅ ok | Low |
| `nixos/modules/specialized/ai-workspace` | — | — | — | — | — | ✅ ok | Low |
| `nixos/modules/specialized/chronicle` | ✅ | — | — | ✅ | — | ✅ ok | Low |
| `nixos/modules/specialized/hackathon` | — | — | — | — | — | ✅ ok | Low |
| `nixos/modules/specialized/nixify` | ✅ | — | — | — | — | ⚠️ CLI commands only (no scripts/ dir) | Medium |
| `nixos/modules/system/lock-manager` | ✅ | — | ✅ | — | — | ⚠️ CLI commands only (no scripts/ dir) | Medium |

## Migration Tasks (auto-generiert)

- [ ] **High Priority** (UI-Struktur korrigieren):

- [ ] **Medium Priority** (CLI-Struktur verbessern):
  - [ ] Add `scripts/` dir for `nixos/core/base/audio` and move CLI entrypoints there (if applicable)
  - [ ] Add `scripts/` dir for `nixos/core/base/boot` and move CLI entrypoints there (if applicable)
  - [ ] Add `scripts/` dir for `nixos/core/base/desktop` and move CLI entrypoints there (if applicable)
  - [ ] Add `scripts/` dir for `nixos/core/base/hardware` and move CLI entrypoints there (if applicable)
  - [ ] Add `scripts/` dir for `nixos/core/base/localization` and move CLI entrypoints there (if applicable)
  - [ ] Add `scripts/` dir for `nixos/core/base/network` and move CLI entrypoints there (if applicable)
  - [ ] Add `scripts/` dir for `nixos/core/base/packages` and move CLI entrypoints there (if applicable)
  - [ ] Add `scripts/` dir for `nixos/core/base/user` and move CLI entrypoints there (if applicable)
  - [ ] Add `scripts/` dir for `nixos/core/management/nixos-control-center` and move CLI entrypoints there (if applicable)
  - [ ] Add `scripts/` dir for `nixos/modules/infrastructure/bootentry-manager` and move CLI entrypoints there (if applicable)
  - [ ] Add `scripts/` dir for `nixos/modules/infrastructure/homelab-manager` and move CLI entrypoints there (if applicable)
  - [ ] Add `scripts/` dir for `nixos/modules/infrastructure/vm` and move CLI entrypoints there (if applicable)
  - [ ] Add `scripts/` dir for `nixos/modules/specialized/nixify` and move CLI entrypoints there (if applicable)
  - [ ] Add `scripts/` dir for `nixos/modules/system/lock-manager` and move CLI entrypoints there (if applicable)

- [ ] **Low Priority** (ok):
  - [x] Modules already aligned with template structure

## TUI-Prioritäten (Empfehlung)

### High Priority (sofort)
1. `nixos/core/management/nixos-control-center` → Hauptmenü (`ncc`)
2. `nixos/core/management/module-manager` → Module enable/disable
3. `nixos/core/management/system-manager` → Build/Update/Rollback
4. `nixos/modules/infrastructure/vm` → VM Start/Stop/Status
5. `nixos/core/base/packages` → Package Manager TUI

### Medium Priority (danach)
6. `nixos/core/base/network` → Net/Troubleshooting
7. `nixos/core/base/desktop` → Desktop Tuning
8. `nixos/core/base/user` → User/Groups
9. `nixos/modules/security/ssh-client-manager` → SSH client (fzf → TUI)
10. `nixos/modules/system/lock-manager` → Locks/Maintenance

### Low Priority (später/optional)
11. `nixos/core/base/audio`
12. `nixos/core/base/hardware`
13. `nixos/core/base/localization`
14. `nixos/modules/security/ssh-server-manager`
15. `nixos/modules/infrastructure/bootentry-manager`
16. `nixos/modules/specialized/nixify` (evtl. Web-UI wichtiger)
17. `nixos/modules/specialized/chronicle` (GUI vorhanden)
18. `nixos/modules/specialized/hackathon`
19. `nixos/modules/specialized/ai-workspace`