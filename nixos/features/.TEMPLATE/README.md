# Module Template

This template defines the recommended structure for **all** NixOS Control Center modules, including:
- **Core modules** (`nixos/core/`) - System-level modules (desktop, hardware, network, etc.)
- **Feature modules** (`nixos/features/`) - Optional feature modules (system-logger, vm-manager, etc.)

## Quick Start

1. Copy this template directory to create a new module
2. Rename `module-name/` to your actual module name
3. Follow the structure defined in this template
4. See `ARCHITECTURE.md` for detailed explanations

## Directory Structure

```
module-name/              # Module name
├── README.md              # Module documentation and usage guide
├── default.nix            # Main module (imports all sub-modules)
├── options.nix            # All configuration options
├── types.nix              # Custom NixOS types (optional)
├── commands.nix          # Command-Center registration (optional, for features)
├── systemd.nix            # Systemd services/timers (optional)
├── config.nix             # Module implementation (optional, split from default.nix if too large)
├── user-configs/          # User-editable config files (optional)
│   └── module-name-config.nix  # User config (symlinked to /etc/nixos/configs/)
├── lib/                   # Shared utility functions
├── scripts/               # Executable CLI commands (user entry points)
├── handlers/              # Business logic orchestration (optional)
├── collectors/            # Data collection modules (optional)
├── processors/            # Data processing/transformation (optional)
├── validators/            # Input validation (optional)
├── formatters/            # Output formatting (optional)
└── tests/                 # Module tests (optional)
```

## Key Files

### `default.nix`
- **ONLY**: Imports all sub-modules
- **MUST NOT**: Contain `config = { ... }` blocks
- **Rule**: If you need implementation → create `config.nix` and import it

### `config.nix`
- **ALL**: Implementation logic, symlink management, system configuration
- Uses `config.core.system-manager.api.configHelpers` for config file management

### `user-configs/`
- User-editable configuration files
- Automatically symlinked to `/etc/nixos/configs/` via `configHelpers.setupConfigFile`

## Using System Manager API

Modules can use the central config helpers via API:

```nix
let
  configHelpers = config.core.system-manager.api.configHelpers;
  defaultConfig = ''{ module-name = { enable = false; }; }'';
in {
  config = {
    system.activationScripts.module-name-config-symlink = 
      configHelpers.setupConfigFile symlinkPath userConfigFile defaultConfig;
  };
}
```

## See Also

- `ARCHITECTURE.md` - Detailed architecture documentation and patterns
- `nixos/core/desktop/` - Example core module
- `nixos/features/system-logger/` - Example feature module

