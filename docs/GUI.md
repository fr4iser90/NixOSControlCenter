Hier ist die **UI‑Matrix pro Modul (CLI / fzf / TUI / GUI / Web)** auf Basis der Repo-Struktur (default.nix, commands/scripts, fzf‑Vorkommen, tui/gui/web‑Ordner). Hinweis: Das ist eine **heuristische Sicht** – wenn du willst, verifizieren wir einzelne Module tiefer.

| Module | CLI | fzf | TUI | GUI | Web |
|---|:--:|:--:|:--:|:--:|:--:|
| `nixos/core/base/audio` | ✅ | — | — | — | — |
| `nixos/core/base/boot` | ✅ | — | — | — | — |
| `nixos/core/base/desktop` | ✅ | — | — | — | — |
| `nixos/core/base/hardware` | ✅ | — | — | — | — |
| `nixos/core/base/localization` | ✅ | — | — | — | — |
| `nixos/core/base/network` | ✅ | — | — | — | — |
| `nixos/core/base/packages` | ✅ | ✅ | — | — | — |
| `nixos/core/base/user` | ✅ | ✅ | — | — | — |
| `nixos/core/management/cli-formatter` | — | ✅ | — | — | — |
| `nixos/core/management/cli-registry` | ✅ | ✅ | — | — | — |
| `nixos/core/management/module-manager` | ✅ | ✅ | ✅ | — | — |
| `nixos/core/management/nixos-control-center` | ✅ | — | — | — | — |
| `nixos/core/management/system-manager` | ✅ | — | ✅ | — | — |
| `nixos/core/management/tui-engine` | ✅ | — | — | — | — |
| `nixos/modules/infrastructure/bootentry-manager` | ✅ | — | — | — | — |
| `nixos/modules/infrastructure/homelab-manager` | ✅ | ✅ | ✅ | — | — |
| `nixos/modules/infrastructure/vm` | ✅ | — | — | — | — |
| `nixos/modules/security/ssh-client-manager` | ✅ | ✅ | — | — | — |
| `nixos/modules/security/ssh-server-manager` | ✅ | — | — | — | — |
| `nixos/modules/specialized/ai-workspace` | — | — | — | — | — |
| `nixos/modules/specialized/chronicle` | ✅ | — | — | ✅ | — |
| `nixos/modules/specialized/hackathon` | — | — | — | — | — |
| `nixos/modules/specialized/nixify` | ✅ | — | — | — | — |
| `nixos/modules/system/lock-manager` | ✅ | — | — | — | — |
