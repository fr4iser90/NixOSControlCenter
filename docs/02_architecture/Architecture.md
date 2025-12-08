
# Module Architecture

## Core vs Features

### Core Modules (`nixos/core/`)

**Purpose**: System-level functionality that is essential for the OS and NCC framework to function.

**Characteristics:**
- **Always Available**: Core modules are fundamental system components
- **Default State**: Usually always enabled, but can be conditionally configured
- **Config Location**: `nixos/core/<domain>/<module-name>/user-configs/<module-name>-config.nix`
- **Config Access**: Via `systemConfig.<domain>.<module-name>` in `flake.nix`
- **Options Path**: `options.systemConfig.<domain>.<module-name>` in `options.nix`
- **Examples**: `core/system/boot/`, `core/system/hardware/`, `core/infrastructure/cli-formatter/`, `core/management/logging/`

**Core Domains:**
- **`system/`** - OS-Level System Components (boot, hardware, network, user, localization, desktop, audio)
- **`infrastructure/`** - NCC Framework Components (cli-formatter, command-center, config)
- **`module-management/`** - Module Management (module-manager for feature enable/disable, version checking)
- **`management/`** - System Management (system-manager, checks, logging, updates)

### Feature Modules (`nixos/features/`)

**Purpose**: Optional features that can be enabled/disabled by the user.

**Characteristics:**
- **Optional**: Features are opt-in and can be enabled/disabled
- **Enable Pattern**: Must check `cfg.enable` before implementation
- **Config Location**: `nixos/features/<domain>/<module-name>/user-configs/<module-name>-config.nix`
- **Config Access**: Via `systemConfig.features.<domain>.<module-name>` in `flake.nix`
- **Options Path**: `options.features.<domain>.<module-name>` in `options.nix`
- **Examples**: `features/system/lock/`, `features/infrastructure/vm/`, `features/security/ssh-client/`

**Feature Domains:**
- **`system/`** - System Monitoring/Management Features (lock, checks, discovery)
- **`infrastructure/`** - Infrastructure Management Features (homelab, vm, bootentry)
- **`security/`** - Security Features (ssh-client, ssh-server, firewall, vpn)
- **`specialized/`** - Specialized/Use-Case Features (ai-workspace, hackathon)

### Key Differences

| Aspect | Core Modules | Feature Modules |
|--------|--------------|-----------------|
| **Location** | `nixos/core/<domain>/<module-name>/` | `nixos/features/<domain>/<module-name>/` |
| **Config Path** | `systemConfig.<domain>.<module-name>` | `systemConfig.features.<domain>.<module-name>` |
| **Options Path** | `options.systemConfig.<domain>.<module-name>` | `options.features.<domain>.<module-name>` |
| **Default State** | Usually always enabled | Opt-in (requires `enable = true`) |
| **Enable Check** | Optional (can be conditional) | Required (`if cfg.enable then ...`) |
| **Purpose** | Essential system/NCC functionality | Optional user features |

### When to Use Core vs Features

**Use Core (`nixos/core/`) when:**
- The module is essential for the OS to boot and run (e.g., `boot/`, `hardware/`, `network/`)
- The module is required for NCC framework to function (e.g., `cli-formatter/`, `command-center/`, `config/`)
- The module is used by other core modules (e.g., `logging/` used by `system-manager/`)
- The module provides fundamental system management (e.g., `system-manager/`, `checks/`)

**Use Features (`nixos/features/`) when:**
- The module is optional and user-selectable (e.g., `vm/`, `ssh-client/`, `ai-workspace/`)
- The module provides specialized functionality (e.g., `hackathon/`, `homelab/`)
- The module can be completely disabled without affecting core functionality

## Recommended Structure: Variant 2 (Domain-Driven Grouping)

### Complete Tree Structure (All Modules Template-Compliant & Versioned)

**Legend:**
- ✅ = Template-compliant (has `default.nix`, `options.nix` with `_version`, `config.nix`, `user-configs/`)
- 📦 = Module is individually versioned
- 📝 = Has optional files (`commands.nix`, `types.nix`, `systemd.nix`, etc.)

```
nixos/
├── core/
│   ├── system/              # System core modules
│   │   ├── boot/            ✅📦
│   │   │   ├── default.nix  (ONLY imports)
│   │   │   ├── options.nix  (_version: "1.0")
│   │   │   ├── config.nix   (ALL implementation)
│   │   │   ├── user-configs/
│   │   │   │   └── boot-config.nix
│   │   │   └── bootloaders/
│   │   │       ├── grub.nix
│   │   │       ├── systemd-boot.nix
│   │   │       └── refind.nix
│   │   │
│   │   ├── hardware/        ✅📦
│   │   │   ├── default.nix  (ONLY imports)
│   │   │   ├── options.nix  (_version: "1.0")
│   │   │   ├── config.nix   (ALL implementation)
│   │   │   ├── user-configs/
│   │   │   │   └── hardware-config.nix
│   │   │   ├── cpu/
│   │   │   ├── gpu/
│   │   │   └── memory/
│   │   │
│   │   ├── network/         ✅📦
│   │   │   ├── default.nix  (ONLY imports)
│   │   │   ├── options.nix  (_version: "1.0")
│   │   │   ├── config.nix   (ALL implementation)
│   │   │   ├── user-configs/
│   │   │   │   └── network-config.nix
│   │   │   ├── firewall.nix
│   │   │   └── networkmanager.nix
│   │   │
│   │   ├── user/            ✅📦
│   │   │   ├── default.nix  (ONLY imports)
│   │   │   ├── options.nix  (_version: "1.0")
│   │   │   ├── config.nix   (ALL implementation)
│   │   │   ├── user-configs/
│   │   │   │   └── user-config.nix
│   │   │   └── home-manager/
│   │   │
│   │   └── localization/    ✅📦
│   │       ├── default.nix  (ONLY imports)
│   │       ├── options.nix  (_version: "1.0")
│   │       ├── config.nix   (ALL implementation)
│   │       └── user-configs/
│   │           └── localization-config.nix
│   │
│   │   ├── desktop/         ✅📦
│   │   │   ├── default.nix  (ONLY imports)
│   │   │   ├── options.nix  (_version: "1.0")
│   │   │   ├── config.nix   (ALL implementation)
│   │   │   ├── user-configs/
│   │   │   │   └── desktop-config.nix
│   │   │   ├── display-managers/
│   │   │   ├── display-servers/
│   │   │   ├── environments/
│   │   │   └── themes/
│   │   │
│   │   └── audio/           ✅📦
│   │       ├── default.nix  (ONLY imports)
│   │       ├── options.nix  (_version: "1.0")
│   │       ├── config.nix   (ALL implementation)
│   │       └── user-configs/
│   │           └── audio-config.nix
│   │
│   ├── infrastructure/      # Infrastructure modules
│   │   ├── cli-formatter/   ✅📦
│   │   │   ├── default.nix  (ONLY imports)
│   │   │   ├── options.nix  (_version: "1.0")
│   │   │   ├── config.nix   (ALL implementation)
│   │   │   ├── user-configs/
│   │   │   │   └── cli-formatter-config.nix
│   │   │   ├── components/
│   │   │   ├── core/
│   │   │   ├── interactive/
│   │   │   └── status/
│   │   │
│   │   ├── command-center/ ✅📦
│   │   │   ├── default.nix  (ONLY imports)
│   │   │   ├── options.nix  (_version: "1.0")
│   │   │   ├── config.nix   (ALL implementation)
│   │   │   ├── user-configs/
│   │   │   │   └── command-center-config.nix
│   │   │   ├── cli/
│   │   │   └── registry/
│   │   │
│   │   └── config/          ✅📦
│   │       ├── default.nix  (ONLY imports)
│   │       ├── options.nix  (_version: "1.0")
│   │       ├── config.nix   (ALL implementation)
│   │       ├── user-configs/
│   │       │   └── config-config.nix
│   │       ├── config-check.nix
│   │       ├── config-migration.nix
│   │       ├── config-validator.nix
│   │       └── config-schema/
│   │
│   ├── module-management/  # Module management domain (NEW)
│   │   └── module-manager/  ✅📦📝
│   │       ├── default.nix  (ONLY imports)
│   │       ├── options.nix  (_version: "1.0")
│   │       ├── commands.nix (Command registration)
│   │       ├── config.nix   (ALL implementation)
│   │       ├── user-configs/
│   │       │   └── module-manager-config.nix
│   │       ├── handlers/
│   │       │   ├── feature-manager.nix
│   │       │   └── module-version-check.nix
│   │       └── lib/
│   │           └── module-registry.nix
│   │
│   └── management/         # System management modules
│       ├── system-manager/  ✅📦📝 (REDUCED scope)
│       │   ├── default.nix  (ONLY imports)
│       │   ├── options.nix  (_version: "1.0")
│       │   ├── commands.nix (Command registration)
│       │   ├── config.nix   (ALL implementation)
│       │   ├── user-configs/
│       │   │   └── system-manager-config.nix
│       │   ├── handlers/
│       │   │   ├── system-update.nix
│       │   │   ├── channel-manager.nix
│       │   │   └── desktop-manager.nix
│       │   ├── scripts/
│       │   ├── lib/
│       │   └── validators/
│       │
│       ├── checks/         ✅📦📝 (moved from features/system-checks)
│       │   ├── default.nix  (ONLY imports)
│       │   ├── options.nix  (_version: "1.0")
│       │   ├── config.nix   (ALL implementation)
│       │   ├── user-configs/
│       │   │   └── checks-config.nix
│       │   ├── prebuild/
│       │   └── postbuild/
│       │
│       ├── logging/        ✅📦📝 (moved from features/system-logger)
│       │   ├── default.nix  (ONLY imports)
│       │   ├── options.nix  (_version: "1.0")
│       │   ├── config.nix   (ALL implementation)
│       │   ├── user-configs/
│       │   │   └── logging-config.nix
│       │   ├── levels.nix
│       │   ├── api.nix
│       │   └── reporting/
│       │       ├── default.nix
│       │       └── collectors/
│       │           ├── bootentries.nix
│       │           ├── bootloader.nix
│       │           ├── profile.nix
│       │           └── packages.nix
│       │
│       └── updates/        ✅📦📝
│           ├── default.nix  (ONLY imports)
│           ├── options.nix  (_version: "1.0")
│           ├── config.nix   (ALL implementation)
│           ├── user-configs/
│           │   └── updates-config.nix
│           └── handlers/
│               └── system-update.nix
│
└── features/                # Feature modules (grouped by domain)
    ├── system/              # System features
    │   ├── lock/            ✅📦📝 (renamed from discovery)
    │   │   ├── default.nix  (ONLY imports)
    │   │   ├── options.nix  (_version: "1.0")
    │   │   ├── config.nix   (ALL implementation)
    │   │   ├── commands.nix (Command registration)
    │   │   ├── user-configs/
    │   │   │   └── lock-config.nix
    │   │   ├── scripts/
    │   │   └── scanners/
    │
    ├── infrastructure/      # Infrastructure features
    │   ├── homelab/         ✅📦📝
    │   │   ├── default.nix  (ONLY imports)
    │   │   ├── options.nix  (_version: "1.0")
    │   │   ├── config.nix   (ALL implementation)
    │   │   ├── commands.nix (Command registration)
    │   │   ├── user-configs/
    │   │   │   └── homelab-config.nix
    │   │   └── lib/
    │   │
    │   ├── vm/              ✅📦📝
    │   │   ├── default.nix  (ONLY imports)
    │   │   ├── options.nix  (_version: "1.0")
    │   │   ├── config.nix   (ALL implementation)
    │   │   ├── commands.nix (Command registration)
    │   │   ├── user-configs/
    │   │   │   └── vm-config.nix
    │   │   ├── base/
    │   │   ├── containers/
    │   │   ├── machines/
    │   │   └── lib/
    │   │
    │   └── bootentry/       ✅📦📝
    │       ├── default.nix  (ONLY imports)
    │       ├── options.nix  (_version: "1.0")
    │       ├── config.nix   (ALL implementation)
    │       ├── commands.nix (Command registration)
    │       ├── user-configs/
    │       │   └── bootentry-config.nix
    │       └── providers/
    │
    ├── security/            # Security features
    │   ├── ssh-client/      ✅📦📝
    │   │   ├── default.nix  (ONLY imports)
    │   │   ├── options.nix  (_version: "1.0")
    │   │   ├── config.nix   (ALL implementation)
    │   │   ├── commands.nix (Command registration)
    │   │   ├── user-configs/
    │   │   │   └── ssh-client-config.nix
    │   │   └── scripts/
    │   │
    │   ├── ssh-server/      ✅📦📝
    │   │   ├── default.nix  (ONLY imports)
    │   │   ├── options.nix  (_version: "1.0")
    │   │   ├── config.nix   (ALL implementation)
    │   │   ├── commands.nix (Command registration)
    │   │   ├── user-configs/
    │   │   │   └── ssh-server-config.nix
    │   │   └── scripts/
    │   │
    │   ├── ssh-tunnel/      ✅📦📝
    │   ├── ssh-proxy/       ✅📦📝
    │   ├── ssh-key-manager/ ✅📦📝
    │   │
    │   └── firewall/        ✅📦📝
    │       ├── default.nix  (ONLY imports)
    │       ├── options.nix  (_version: "1.0")
    │       ├── config.nix   (ALL implementation)
    │       └── user-configs/
    │           └── firewall-config.nix
    │
    └── specialized/         # Specialized features
        ├── ai-workspace/    ✅📦📝
        │   ├── default.nix  (ONLY imports)
        │   ├── options.nix  (_version: "1.0")
        │   ├── config.nix   (ALL implementation)
        │   ├── user-configs/
        │   │   └── ai-workspace-config.nix
        │   ├── containers/
        │   ├── llm/
        │   └── services/
        │
        └── hackathon/       ✅📦📝
            ├── default.nix  (ONLY imports)
            ├── options.nix  (_version: "1.0")
            ├── config.nix   (ALL implementation)
            ├── commands.nix (Command registration)
            └── user-configs/
                └── hackathon-config.nix
```

### Template Compliance Summary

**All Modules (Core & Features) follow the same structure:**

1. ✅ **`default.nix`** - ONLY imports, NO `config = { ... }` blocks
2. ✅ **`options.nix`** - ALL option definitions with `_version` (individual versioning)
3. ✅ **`config.nix`** - ALL implementation (symlink management, system config)
4. ✅ **`user-configs/`** - User-editable config files (symlinked to `/etc/nixos/configs/`)
5. 📝 **Optional files** - `commands.nix`, `types.nix`, `systemd.nix` (only when needed)
6. 📝 **Optional directories** - `scripts/`, `handlers/`, `collectors/`, etc. (only when needed)

**Versioning:**
- 📦 **Every module** has `_version` in `options.nix`
- 📦 **Individual versioning** - Each module manages its own version
- 📦 **Migration support** - Each module can have `migrations/` directory

## Module Template Compliance Matrix

| Module | default.nix | options.nix | config.nix | user-configs/ | commands.nix | scripts/ | handlers/ | collectors/ | lib/ | migrations/ |
|--------|-------------|-------------|------------|----------------|--------------|----------|-----------|-------------|------|-------------|
| **Core Modules** |
| `core/system/boot` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| `core/system/hardware` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| `core/system/network` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| `core/system/user` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| `core/system/localization` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| `core/system/desktop` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| `core/system/audio` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| `core/infrastructure/cli-formatter` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| `core/infrastructure/command-center` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| `core/infrastructure/config` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| `core/module-management/module-manager` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ |
| `core/management/system-manager` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ✅ | ✅ | (REDUCED: System Updates, Channel, Desktop only) |
| `core/management/checks` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| `core/management/logging` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ❌ | ✅ |
| `core/management/updates` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | ❌ | ✅ |
| **Feature Modules** |
| `features/system/lock` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| `features/infrastructure/homelab` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ |
| `features/infrastructure/vm` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ | ✅ |
| `features/infrastructure/bootentry` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| `features/security/ssh-client` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| `features/security/ssh-server` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| `features/security/ssh-tunnel` | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| `features/security/firewall` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| `features/specialized/ai-workspace` | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ |
| `features/specialized/hackathon` | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |

**Legend:**
- ✅ = Required or present
- ❌ = Not needed/not present
- All modules have: `default.nix`, `options.nix` (with `_version`), `config.nix`, `user-configs/`
- Optional components depend on module functionality

## Module Mapping

### Core Modules (Current → New)

| Current | New Location |
|---------|--------------|
| `core/boot/` | `core/system/boot/` |
| `core/hardware/` | `core/system/hardware/` |
| `core/network/` | `core/system/network/` |
| `core/user/` | `core/system/user/` |
| `core/localization/` | `core/system/localization/` |
| `core/desktop/` | `core/system/desktop/` |
| `core/audio/` | `core/system/audio/` |
| `core/cli-formatter/` | `core/infrastructure/cli-formatter/` |
| `core/command-center/` | `core/infrastructure/command-center/` |
| `core/config/` | `core/infrastructure/config/` |
| `core/system-manager/` (split) | `core/module-management/module-manager/` (Feature Enable/Disable, Version Checking) |
| `core/system-manager/` (split) | `core/management/system-manager/` (System Updates, Channel, Desktop) |

### New Core Modules

| Source | New Location | Reason |
|--------|--------------|--------|
| `features/system-logger/` | `core/management/logging/` | Used by Core modules (system-manager) |
| `features/system-checks/` | `core/management/checks/` | Used by Core modules (hardware auto-detect, system-update) |
| `system-manager/handlers/feature-manager.nix` | `core/module-management/module-manager/handlers/` | Module Management (Feature Enable/Disable) |
| `system-manager/handlers/module-version-check.nix` | `core/module-management/module-manager/handlers/` | Module Management (Version Checking) |
| `system-manager/handlers/system-update.nix` | `core/management/system-manager/handlers/` | System Management (System Updates) |

### Feature Modules (Current → New)

| Current | New Location | Notes |
|---------|--------------|-------|
| `features/system-discovery/` | `features/system/lock/` | **Renamed**: `system-discovery` → `system-lock` (see naming rationale below) |
| ~~`features/system-config-manager/`~~ | ~~removed~~ | **Removed**: Desktop-Config already in `core/desktop/`, Feature Enable/Disable already in `core/system-manager/handlers/feature-manager.nix` |
| `features/homelab-manager/` | `features/infrastructure/homelab/` |
| `features/vm-manager/` | `features/infrastructure/vm/` |
| `features/bootentry-manager/` | `features/infrastructure/bootentry/` |
| `features/ssh-client-manager/` | `features/security/ssh-client/` |
| `features/ssh-server-manager/` | `features/security/ssh-server/` |
| `features/ai-workspace/` | `features/specialized/ai-workspace/` |
| `features/hackathon-manager/` | `features/specialized/hackathon/` |

## Template Compliance & Versioning

### All Modules Follow Template Structure

**Every module (Core & Features) now has:**

1. **`default.nix`** - ONLY imports, NO `config` blocks
   - Pattern: `imports = [ ./options.nix ] ++ (if cfg.enable then [ ./config.nix ] else [ ./config.nix ])`

2. **`options.nix`** - ALL option definitions with `_version`
   - Pattern: `_version = lib.mkOption { type = lib.types.str; default = "1.0"; internal = true; }`
   - **Individual versioning**: Each module has its own version

3. **`config.nix`** - ALL implementation logic
   - Symlink management (always runs)
   - System configuration (only when enabled)
   - Assertions and validations

4. **`user-configs/`** - User-editable config files
   - Pattern: `module-name/user-configs/module-name-config.nix`
   - Symlinked to `/etc/nixos/configs/module-name-config.nix`

5. **Optional files** (only when needed):
   - `commands.nix` - Command registration (features with CLI)
   - `types.nix` - Custom types
   - `systemd.nix` - Systemd services/timers

6. **Optional directories** (only when needed):
   - `scripts/` - CLI entry points
   - `handlers/` - Orchestration
   - `collectors/` - Data gathering
   - `processors/` - Data transformation
   - `validators/` - Input validation
   - `formatters/` - Output formatting
   - `lib/` - Shared utilities
   - `migrations/` - Version migrations

### Versioning Strategy

**Individual Module Versioning:**
- Each module defines `_version` in `options.nix`
- Modules are versioned independently
- Migration support per module via `migrations/` directory
- Version detection: `cfg._version` or option presence detection

**Example:**
```nix
# options.nix
let moduleVersion = "1.0"; in {
  options.features.my-feature = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
    };
    # ... other options
  };
}
```

## Grouping Strategy: Domain-Driven, All Flat

### Decision Rule: ONE Pattern - Domain-Grouped, All Flat

**Rule**: **ALL modules (Core & Features) are domain-grouped and flat within their domain. NO sub-groups.**

### Domain Definitions

**Core Domains:**

| Domain | Purpose | Examples |
|--------|---------|----------|
| **`system/`** | **OS-Level System Components** - Fundamental system configuration that the OS needs to boot and run | `boot/`, `hardware/`, `network/`, `user/`, `localization/`, `desktop/`, `audio/` |
| **`infrastructure/`** | **NCC Framework Components** - Core infrastructure/tooling that NCC itself needs to function | `cli-formatter/`, `command-center/`, `config/` |
| **`module-management/`** | **Module Management** - Manages module lifecycle, registration, and versioning | `module-manager/` (Feature Enable/Disable, Version Checking) |
| **`management/`** | **System Management** - Tools for managing the system (updates, logging, system operations) | `system-manager/`, `checks/`, `logging/`, `updates/` |

**Features Domains:**

| Domain | Purpose | Examples |
|--------|---------|----------|
| **`system/`** | **System Monitoring/Management Features** - Features that monitor, check, or manage the system | `checks/`, `discovery/`, `config-manager/` |
| **`infrastructure/`** | **Infrastructure Management Features** - Features for managing infrastructure (VMs, containers, homelab) | `homelab/`, `vm/`, `bootentry/` |
| **`security/`** | **Security Features** - Security-related tools and configurations | `ssh-client/`, `ssh-server/`, `firewall/`, `vpn/` |
| **`specialized/`** | **Specialized/Use-Case Features** - Domain-specific or specialized use cases | `ai-workspace/`, `hackathon/` |

**Key Distinction: `system/` vs `infrastructure/`**

- **`core/system/`** = OS-Level (what the OS needs: boot, hardware, network)
- **`core/infrastructure/`** = NCC Framework (what NCC needs: CLI, commands, config system)
- **`features/system/`** = System monitoring/management (checks, discovery, config management)
- **`features/infrastructure/`** = Infrastructure management (VMs, homelab, containers)

**Pattern: Domain-Grouped, All Flat**

**Core Structure:**
```
core/
├── system/              # Domain: System core
│   ├── boot/            ✅ (flat within domain)
│   ├── hardware/        ✅ (flat within domain)
│   ├── network/         ✅ (flat within domain)
│   ├── user/            ✅ (flat within domain)
│   ├── localization/    ✅ (flat within domain)
│   ├── desktop/         ✅ (flat within domain)
│   └── audio/           ✅ (flat within domain)
├── infrastructure/      # Domain: Infrastructure
│   ├── cli-formatter/   ✅ (flat within domain)
│   ├── command-center/ ✅ (flat within domain)
│   └── config/          ✅ (flat within domain)
├── module-management/  # Domain: Module Management (NEW)
│   └── module-manager/  ✅ (flat within domain)
└── management/          # Domain: Management
    ├── system-manager/  ✅ (flat within domain)
    ├── checks/          ✅ (flat within domain)
    ├── logging/         ✅ (flat within domain)
    └── updates/         ✅ (flat within domain)
```

**Features Structure:**
```
features/
├── system/              # Domain: System features
│   └── lock/            ✅ (flat within domain) - System state lock file (renamed from discovery)
├── security/            # Domain: Security features
│   ├── ssh-client/      ✅ (flat within domain)
│   ├── ssh-server/      ✅ (flat within domain)
│   ├── ssh-tunnel/      ✅ (flat within domain)
│   ├── firewall/        ✅ (flat within domain)
│   └── vpn/             ✅ (flat within domain)
└── infrastructure/      # Domain: Infrastructure features
    ├── homelab/         ✅ (flat within domain)
    ├── vm/              ✅ (flat within domain)
    └── bootentry/       ✅ (flat within domain)
```

**Benefits:**
- ✅ **Consistent** - ONE pattern for ALL (Core & Features)
- ✅ **Domain-organized** - Clear categorization by domain
- ✅ **Scalable** - Domain grouping handles 100+ modules per domain
- ✅ **Simple** - No sub-groups, no conditions, no exceptions
- ✅ **Professional** - Domain-Driven Design pattern

## Import Path Changes

### Before
```nix
imports = [
  ./core/boot
  ./core/hardware
  ./features/system-logger
  ./features/vm-manager
];
```

### After (Domain-Grouped, All Flat)
```nix
imports = [
  ./core/system/boot
  ./core/system/hardware
  ./core/management/checks
  ./core/management/logging
  ./features/system/lock
  ./features/infrastructure/vm
  ./features/infrastructure/homelab
  ./features/security/ssh-client
  ./features/security/ssh-server
  ./features/security/firewall
];
```

## Module Relocation Summary

### Modules Moved to Core

**Reason**: These modules are used by Core modules and are essential system components.

1. **`system-checks`** → `core/management/checks/`
   - **Used by**: `core/hardware/` (auto-detect), `core/system-manager/handlers/system-update.nix` (pre-build checks)
   - **Default**: Enabled (`true` in defaultConfig)

2. **`system-logger`** → `core/management/logging/`
   - **Used by**: `core/system-manager` (system reports)
   - **Default**: Enabled (`true` in defaultConfig)

### Modules Removed

1. **`system-config-manager`** → **REMOVED**
   - **Reason**: Duplicate functionality
   - Desktop-Config → Already in `core/desktop/`
   - Feature Enable/Disable → Already in `core/system-manager/handlers/feature-manager.nix`

### Modules Renamed

1. **`system-discovery`** → **`system-lock`**
   - **Reason**: Professional naming convention (see below)
   - **Rationale**: Captures exact system state (versions, hashes, timestamps) for Git commit and reproducibility
   - **Naming Convention**: **Lock** = exact state capture (like `package-lock.json`, `yarn.lock`)
   - **Alternative considered**: `system-manifest` (but Manifest = declarative "what should be", Lock = exact "what is")

## Naming Rationale: Lock vs Manifest

### Professional Distinction

**Manifest** = Declarative description (what SHOULD be):
- Example: `package.json` (dependencies without exact versions)
- Example: `docker-compose.yml` (services, but no image hashes)
- Purpose: Describes desired state

**Lock / Snapshot / Lockfile** = Exact capture of current state (versions, hashes, timestamps):
- Example: `package-lock.json` (exact versions, hashes, timestamps)
- Example: `yarn.lock`, `Pipfile.lock` (exact version pins)
- Purpose: Reproducible state capture for Git commit

### Why `system-lock`?

The feature captures:
- ✅ Exact package versions
- ✅ Exact addon/extension versions
- ✅ Exact configuration state
- ✅ Timestamps and metadata
- ✅ For Git commit and reproducibility

This is a **Lock file**, not a Manifest!

### Professional Examples

| Tool/System | Lock File | Purpose |
|------------|-----------|---------|
| NPM | `package-lock.json` | Exact dependency versions |
| Yarn | `yarn.lock` | Exact dependency versions |
| Pip | `Pipfile.lock` | Exact Python package versions |
| Cargo | `Cargo.lock` | Exact Rust dependency versions |
| **NCC** | `system-lock.json` | Exact system state (packages, addons, configs) |

### Commands

- `ncc lock create` - Create system lock file
- `ncc lock restore` - Restore from lock file
- `ncc lock diff` - Compare current state with lock file

## Module Management Architecture

### Who Manages Module Imports?

**Module Import Flow:**

1. **`flake.nix`** → Imports base modules
   - Imports: `./core`, `./features`, `./packages`, `./custom`
   - No management logic, just imports

2. **`features/default.nix`** → Auto-Discovery & Auto-Registration
   - Reads `features/` directory
   - Validates features
   - Resolves dependencies
   - Sorts by dependencies
   - Imports enabled features

3. **`core/module-management/module-manager/`** → Module Management
   - Feature Enable/Disable (`feature-manager.nix`)
   - Module Version Checking (`module-version-check.nix`)
   - Module Registry (future: centralized module registry API)

### Module Management Domain

**New Domain: `core/module-management/`**

**Purpose**: Manages module lifecycle, registration, and versioning

**Structure:**
```
core/
├── module-management/      # NEW: Module Management Domain
│   └── module-manager/     ✅📦📝
│       ├── default.nix     (ONLY imports)
│       ├── options.nix     (_version: "1.0")
│       ├── commands.nix    (Command registration)
│       ├── config.nix      (ALL implementation)
│       ├── user-configs/
│       │   └── module-manager-config.nix
│       ├── handlers/
│       │   ├── feature-manager.nix      # Feature Enable/Disable
│       │   └── module-version-check.nix  # Version checking
│       └── lib/
│           └── module-registry.nix      # Module registry (future)
```

**Responsibilities:**
- ✅ Feature Enable/Disable management
- ✅ Module version checking
- ✅ Module registry (future: centralized module discovery)
- ✅ Module dependency resolution (works with `features/default.nix`)

### System Management Domain (Reduced)

**`core/management/system-manager/`** → Reduced scope

**Responsibilities (after split):**
- ✅ System Updates (`system-update.nix`)
- ✅ Channel Management (`channel-manager.nix`)
- ✅ Desktop Management (`desktop-manager.nix`)
- ✅ Config Helpers API (config file management, backups)

**Removed from `system-manager`:**
- ❌ Feature Enable/Disable → Moved to `module-management/module-manager`
- ❌ Module Version Checking → Moved to `module-management/module-manager`

### Module Mapping Update

**Core Modules (Current → New):**

| Current | New Location | Reason |
|---------|--------------|--------|
| `core/system-manager/handlers/feature-manager.nix` | `core/module-management/module-manager/handlers/` | Module Management (Feature Enable/Disable) |
| `core/system-manager/handlers/module-version-check.nix` | `core/module-management/module-manager/handlers/` | Module Management (Version Checking) |
| `core/system-manager/handlers/system-update.nix` | `core/management/system-manager/handlers/` | System Management (System Updates) |
| `core/system-manager/handlers/channel-manager.nix` | `core/management/system-manager/handlers/` | System Management (Channel Management) |
| `core/system-manager/handlers/desktop-manager.nix` | `core/management/system-manager/handlers/` | System Management (Desktop Management) |

**Split Logic:**
- **Module Management** = Module lifecycle, registration, versioning
- **System Management** = System operations, updates, configuration

### Benefits of Separation

1. ✅ **Clear Separation**: Module Management ≠ System Management
2. ✅ **Domain-Driven**: Own domain for module management
3. ✅ **Scalable**: Can be extended (Module Registry API, Module Discovery, etc.)
4. ✅ **Professional**: Clear responsibilities, follows Domain-Driven Design

