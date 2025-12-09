# Module Architecture

## Unified Module System

NCC uses a **unified module system** where all modules follow the same structure and API patterns. Every module is equal - there are no artificial distinctions between "core" or "features". All modules are simply modules with different default behaviors.

### Module Categories

All modules are organized under `systemConfig.*` with three logical categories:

| Category | Namespace | Purpose | Enable Default | Examples |
|----------|-----------|---------|----------------|----------|
| **Core System** | `systemConfig.core.system.*` | Core OS functionality | `true` | `boot/`, `audio/`, `hardware/`, `desktop/` |
| **Core Management** | `systemConfig.core.management.*` | System management tools | `true` | `logging/`, `checks/`, `system-manager/`, `updates/` |
| **Core Infrastructure** | `systemConfig.core.infrastructure.*` | Core infrastructure | `true` | `cli-formatter/`, `command-center/` |
| **Features** | `systemConfig.features.*` | Optional user features | `false` | `homelab/`, `vm/`, `ssh-client/`, `lock/` |

### Configuration Pattern

**All modules use the same pattern**:

```nix
# options.nix - ALL modules follow this structure
options.systemConfig.system.module-name = {
  _version = lib.mkOption { /* versioning */ };
  enable = lib.mkOption {
    type = lib.types.bool;
    default = /* true for system/management, false for features */;
    description = "...";
  };
  # ... module-specific options
};

# default.nix - ALL modules follow this structure
{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.system.module-name or {};  # or management.* or features.*
in {
  imports = [
    ./options.nix
  ] ++ (if (cfg.enable or false) then [
    ./config.nix  # Implementation logic
  ] else [
    ./config.nix  # Symlink management (always)
  ]);
};

# config.nix - ALL modules follow this structure
{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.system.module-name or {};
  userConfigFile = ./module-name-config.nix;
  symlinkPath = "/etc/nixos/configs/module-name-config.nix";
in
  lib.mkMerge [
    {
      # Symlink management (ALWAYS RUNS)
      system.activationScripts.module-name-config-symlink = ''
        # Create symlink and default config
      '';
    }
    (lib.mkIf (cfg.enable or false) {
      # Module implementation (ONLY WHEN ENABLED)
      # System configuration
      # Assertions
    })
  ];
```

### Key Architecture Principles

1. **Unified API**: All modules use `systemConfig.*` namespace
2. **Equal Treatment**: Every module has `enable` option with category-specific defaults
3. **Separation of Concerns**: `default.nix` only imports, `config.nix` does everything else
4. **Versioning**: Each module manages its own version via `_version`
5. **User Configs**: Each module has user-editable config
6. **Symlink Management**: Automatic symlinking to `/etc/nixos/configs/`

## Complete Module Tree (All Template-Compliant & Versioned)

```
systemConfig = {
  # ==========================================
  # CORE MODULES (enable = true by default)
  # ==========================================
  core = {
    system = {
      boot = { enable = true; /* bootloader, initrd, kernel */ };
      hardware = { enable = true; /* gpu, cpu, sensors */ };
      network = { enable = true; /* networkmanager, firewall */ };
      user = { enable = true; /* user management */ };
      localization = { enable = true; /* locale, timezone */ };
      desktop = { enable = true; /* kde, gnome, xfce */ };
      audio = { enable = true; /* pipewire, pulseaudio */ };
      packages = { enable = true; /* system packages */ };
    };

    management = {
      module-manager = { enable = true; /* feature enable/disable */ };
      logging = { enable = true; /* system logging */ };
      checks = { enable = true; /* health checks */ };
      system-manager = { enable = true; /* updates, channels */ };
      command-center = { enable = true; /* CLI commands */ };
      updates = { enable = true; /* update management */ };
    };

    infrastructure = {
      cli-formatter = { enable = true; /* UI formatting */ };
    };
  };

  # ==========================================
  # FEATURES CATEGORY (enable = false by default)
  # ==========================================
  features = {
    infrastructure = {
      homelab = { enable = false; /* docker stacks */ };
      vm = { enable = false; /* qemu/kvm */ };
      bootentry = { enable = false; /* boot manager */ };
    };
    security = {
      ssh-client = { enable = false; /* ssh tools */ };
      ssh-server = { enable = false; /* openssh */ };
      lock = { enable = false; /* system lock */ };
      firewall = { enable = false; /* advanced firewall */ };
    };
    specialized = {
      ai-workspace = { enable = false; /* ML tools */ };
      hackathon = { enable = false; /* dev tools */ };
    };
  };
};
```

## File Structure for All Modules

Every module follows this template structure:

```
module-name/
├── README.md              # Documentation
├── default.nix            # ONLY imports
├── options.nix            # ALL option definitions with _version
├── config.nix             # ALL implementation logic
├── commands.nix           # CLI commands (optional)
├── types.nix              # Custom Nix types (optional)
├── systemd.nix            # Systemd services (optional)
├── module-name-config.nix # User-editable config
├── scripts/               # CLI entry points (optional)
│   ├── script-1.nix
│   └── script-2.nix
├── handlers/              # Business logic (optional)
├── collectors/            # Data gathering (optional)
├── processors/            # Data processing (optional)
├── validators/            # Input validation (optional)
├── formatters/            # Output formatting (optional)
├── lib/                   # Shared utilities (optional)
├── migrations/            # Version migrations (optional)
└── tests/                 # Module tests (optional)
```

## Module Management

### Who Manages Activation?

1. **Module-Manager**: Toggles enable/disable states centrally
   - Located: `systemConfig.management.module-manager`
   - Command: `ncc feature-manager`
   - Manages: All modules' enable states

2. **Auto-Discovery**: Feature modules register themselves
   - Located: `features/default.nix`
   - Function: Discovers and imports enabled feature modules

3. **User Config**: Manual control in configs
   - Location: `/etc/nixos/configs/module-manager-config.nix`
   - Access: Auto-symlinked from `module-manager/`

### Enable/Disable Flow

```bash
# Toggle any module (system, management, or features)
sudo ncc feature-manager  # Select any module, toggle enable/disable

# Manual config
{
  systemConfig = {
    system = { desktop = { enable = true; }; };
    management = { logging = { enable = true; }; };
    features = { infrastructure = { homelab = { enable = true; }; }; };
  };
}
```

## Benefits of This Architecture

1. **Consistency**: One API for all modules (`systemConfig.*`)
2. **Flexibility**: All modules can be toggled, no artificial restrictions
3. **Safety**: Intelligent defaults (core=true, features=false) prevent breaking systems
4. **Scalability**: Easy to add new modules in any category
5. **Maintainability**: Clear separation between module structure and implementation
6. **Versioning**: Each module can evolve independently
7. **User Control**: Everything is configurable, but sensibly defaulted

## Migration from Old System

### What Changed

**Before**: Inconsistent namespaces (`systemConfig.*` vs `features.*`)
```nix
# OLD - Inconsistent
options.systemConfig.management.logging = { ... };
options.features.infrastructure.homelab = { ... };
```

**After**: Unified namespace with categories
```nix
# NEW - Unified & consistent
options.systemConfig.management.logging = { ... };
options.systemConfig.features.infrastructure.homelab = { ... };
```

### Automatic Migration

Modules can migrate with backward compatibility:
- Old `options.systemConfig.*` paths still work
- `options.features.*` redirects to `options.systemConfig.features.*`
- Migration scripts handle option renaming

### Template Compliance

**All modules now follow the same template** (as defined in this architecture). No more special cases or exceptions.
