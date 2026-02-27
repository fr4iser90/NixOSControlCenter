# NCC Domain Structure

Complete overview of all domains and their commands.

---

## Domain Overview

```
ncc

=== NixOS Control Center ===

Core:
  system        - System lifecycle management
  modules       - Module management
  desktop       - Desktop environment management

Infrastructure:
  vm            - Virtual machine management

Specialized:
  chronicle     - Digital work memory
  nixify        - System DNA extractor

Use: ncc <domain> help
```

---

## Core Domains

### `system` - System Lifecycle Management

**Module:** `core/management/system-manager`

**TUI:** `ncc system`

**Commands:**
```bash
ncc system build                # Build and activate NixOS configuration
ncc system update               # Update NixOS from repository
ncc system update-channels      # Update Nix flake inputs/channels
ncc system rollback             # Rollback to previous generation

ncc system report               # Generate system report
ncc system check-versions       # Check module versions
ncc system update-modules       # Update modules with migration

ncc system migrate-config       # Migrate to modular structure
ncc system validate-config      # Validate configuration
```

**Current (Flat) → New (Hierarchical):**
| Current | New |
|---------|-----|
| `ncc build` | `ncc system build` |
| `ncc system-update` | `ncc system update` |
| `ncc update-channels` | `ncc system update-channels` |
| `ncc log-system-report` | `ncc system report` |
| `ncc check-module-versions` | `ncc system check-versions` |
| `ncc update-modules` | `ncc system update-modules` |
| `ncc migrate-system-config` | `ncc system migrate-config` |
| `ncc validate-system-config` | `ncc system validate-config` |

---

### `modules` - Module Management

**Module:** `core/management/module-manager`

**TUI:** `ncc modules`

**Commands:**
```bash
ncc modules enable <module>     # Enable a module
ncc modules disable <module>    # Disable a module
ncc modules list                # List all modules
ncc modules status              # Show module status
ncc modules check-versions      # Check module versions
ncc modules update              # Update modules
```

**Current (Flat) → New (Hierarchical):**
| Current | New | Notes |
|---------|-----|-------|
| `ncc module-manager` | `ncc modules` | TUI launcher |
| - | `ncc modules enable` | New CLI command |
| - | `ncc modules disable` | New CLI command |

---

### `desktop` - Desktop Environment Management

**Module:** `core/base/desktop`

**TUI:** `ncc desktop`

**Commands:**
```bash
ncc desktop enable <name>       # Enable desktop environment
ncc desktop disable             # Disable desktop environment
ncc desktop list                # List available desktops
ncc desktop status              # Show current desktop
```

**Current (Flat) → New (Hierarchical):**
| Current | New | Notes |
|---------|-----|-------|
| `ncc desktop-manager` | `ncc desktop` | TUI launcher |
| - | `ncc desktop enable` | New CLI command |
| - | `ncc desktop disable` | New CLI command |

---

## Infrastructure Domains

### `vm` - Virtual Machine Management

**Module:** `modules/infrastructure/vm`

**TUI:** `ncc vm`

**Commands:**
```bash
# Status & Info
ncc vm status                   # Show VM manager status
ncc vm list                     # List available distros

# Test VMs
ncc vm test <distro> run        # Start test VM
ncc vm test <distro> reset      # Reset test VM

# Available distros:
# arch, fedora, kali, mint, nixos, pop, ubuntu, zorin
```

**Current (Flat) → New (Hierarchical):**
| Current | New | Notes |
|---------|-----|-------|
| `ncc vm` | `ncc vm` | Keep as TUI |
| `ncc vm-status` | `ncc vm status` | Rename to subcommand |
| `ncc vm-list` | `ncc vm list` | Rename to subcommand |
| `ncc test-arch-run` | `ncc vm test arch run` | Hierarchical |
| `ncc test-arch-reset` | `ncc vm test arch reset` | Hierarchical |
| `ncc test-fedora-run` | `ncc vm test fedora run` | Hierarchical |
| `ncc test-fedora-reset` | `ncc vm test fedora reset` | Hierarchical |
| `ncc test-kali-run` | `ncc vm test kali run` | Hierarchical |
| `ncc test-kali-reset` | `ncc vm test kali reset` | Hierarchical |
| `ncc test-mint-run` | `ncc vm test mint run` | Hierarchical |
| `ncc test-mint-reset` | `ncc vm test mint reset` | Hierarchical |
| `ncc test-nixos-run` | `ncc vm test nixos run` | Hierarchical |
| `ncc test-nixos-reset` | `ncc vm test nixos reset` | Hierarchical |
| `ncc test-pop-run` | `ncc vm test pop run` | Hierarchical |
| `ncc test-pop-reset` | `ncc vm test pop reset` | Hierarchical |
| `ncc test-ubuntu-run` | `ncc vm test ubuntu run` | Hierarchical |
| `ncc test-ubuntu-reset` | `ncc vm test ubuntu reset` | Hierarchical |
| `ncc test-zorin-run` | `ncc vm test zorin run` | Hierarchical |
| `ncc test-zorin-reset` | `ncc vm test zorin reset` | Hierarchical |

**Impact:** 22 flat commands → 1 domain + subcommands!

---

## Specialized Domains

### `chronicle` - Digital Work Memory

**Module:** `modules/specialized/chronicle`

**TUI:** `ncc chronicle`

**Commands:**
```bash
ncc chronicle start             # Start recording session
ncc chronicle stop              # Stop current recording
ncc chronicle capture           # Manually capture a step
ncc chronicle status            # Show recording status
ncc chronicle list              # List all recordings
ncc chronicle cleanup           # Remove old recordings
ncc chronicle test              # Run system tests
```

**Current (Flat) → New (Hierarchical):**
| Current | New | Notes |
|---------|-----|-------|
| `ncc chronicle` | `ncc chronicle` | Already correct! |
| `ncc chronicle start` | `ncc chronicle start` | Already correct! |
| `ncc chronicle stop` | `ncc chronicle stop` | Already correct! |

**Status:** ✅ Already follows pattern!

---

### `nixify` - System DNA Extractor

**Module:** `modules/specialized/nixify`

**TUI:** `ncc nixify`

**Commands:**
```bash
ncc nixify extract              # Extract system configuration
ncc nixify iso build            # Build installation ISO
ncc nixify iso test             # Test ISO in VM
ncc nixify config preview       # Preview generated config
```

**Current (Flat) → New (Hierarchical):**
| Current | New | Notes |
|---------|-----|-------|
| `ncc nixify` | `ncc nixify` | Already correct! |

**Status:** ✅ Already follows pattern!

---

## Migration Summary

### Commands by Impact

**Must Rename (30 commands):**
- All VM test commands (16 commands) → `ncc vm test <distro> <action>`
- `ncc vm-status` → `ncc vm status`
- `ncc vm-list` → `ncc vm list`
- `ncc build` → `ncc system build`
- `ncc system-update` → `ncc system update`
- `ncc update-channels` → `ncc system update-channels`
- `ncc desktop-manager` → `ncc desktop`
- `ncc module-manager` → `ncc modules`
- `ncc log-system-report` → `ncc system report`
- `ncc check-module-versions` → `ncc system check-versions`
- `ncc update-modules` → `ncc system update-modules`
- `ncc migrate-system-config` → `ncc system migrate-config`
- `ncc validate-system-config` → `ncc system validate-config`

**Already Correct (2 domains):**
- `ncc chronicle *` - Already hierarchical ✅
- `ncc nixify *` - Already hierarchical ✅

---

## Final Structure

### `ncc` Output (Top-Level)

**Before (39 commands):**
```
Available commands:
  update-channels
  chronicle
  module-manager
  nixify
  build
  log-system-report
  check-module-versions
  update-modules
  migrate-system-config
  validate-system-config
  desktop-manager
  system-update
  vm
  vm-status
  vm-list
  test-arch-run
  test-arch-reset
  ... (+16 more test commands)
```

**After (6 domains):**
```
=== NixOS Control Center ===

Core:
  system        - System lifecycle management
  modules       - Module management
  desktop       - Desktop environment

Infrastructure:
  vm            - Virtual machine management

Specialized:
  chronicle     - Digital work memory
  nixify        - System DNA extractor

Use: ncc <domain> help
```

**Reduction:** 39 → 6 (85% cleaner!)

---

## Domain Details

For detailed TUI mockups and command examples, see:
- [CLI-PATTERN.md](./CLI-PATTERN.md) - Pattern rules
- [MIGRATION.md](./MIGRATION.md) - Migration plan

---

## This Is The Structure

Clean. Hierarchical. Professional.

Like it should be.
