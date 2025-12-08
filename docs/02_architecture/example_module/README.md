# Example Module Template

This is a **complete template module** that demonstrates the recommended structure for all NixOS Control Center modules.

## Quick Start

### Copy Template to Create New Module

**Important**: All modules must be placed in their respective domain directories!

```bash
# For a new feature module (choose appropriate domain: system/, infrastructure/, security/, specialized/)
cp -r docs/02_architecture/example_module nixos/features/system/my-new-feature
# OR
cp -r docs/02_architecture/example_module nixos/features/infrastructure/my-new-feature
# OR
cp -r docs/02_architecture/example_module nixos/features/security/my-new-feature
# OR
cp -r docs/02_architecture/example_module nixos/features/specialized/my-new-feature

# For a new core module (choose appropriate domain: system/, infrastructure/, module-management/, management/, desktop/, audio/)
cp -r docs/02_architecture/example_module nixos/core/system/my-new-module
# OR
cp -r docs/02_architecture/example_module nixos/core/infrastructure/my-new-module
# OR
cp -r docs/02_architecture/example_module nixos/core/module-management/my-new-module
# OR
cp -r docs/02_architecture/example_module nixos/core/management/my-new-module
# OR
cp -r docs/02_architecture/example_module nixos/core/desktop/my-new-module
# OR
cp -r docs/02_architecture/example_module nixos/core/audio/my-new-module
```

**Domain Selection:**
- See [Architecture.md](../Architecture.md) for domain definitions and examples
- Choose the domain that best matches your module's purpose

### After Copying

1. **Rename files and directories:**
   - Replace `example-module` with your module name
   - Update all references in files

2. **Update `default.nix`:**
   - Change `cfg = systemConfig.features.example-module` to your module path
   - Update imports as needed

3. **Update `options.nix`:**
   - Change `options.features.example-module` to your module path
   - Define your actual options

4. **Update `config.nix`:**
   - Change all `example-module` references
   - Update `userConfigFile` and `symlinkPath` paths
   - Implement your module logic

5. **Update `commands.nix`:**
   - Change command names and scripts
   - Update command metadata

6. **Update `user-configs/example-module-config.nix`:**
   - Rename file to match your module name
   - Update config structure

## Structure Overview

```
example-module/
├── default.nix          # ONLY imports (no config blocks!)
├── options.nix          # ALL option definitions
├── config.nix           # ALL implementation logic
├── commands.nix         # Command registration (features only)
├── types.nix            # Custom types (optional)
├── systemd.nix          # Systemd services (optional)
├── user-configs/        # User-editable configs
├── scripts/             # CLI entry points
├── handlers/            # Orchestration layer
├── collectors/          # Data gathering
├── processors/          # Data transformation
├── validators/          # Input validation
├── formatters/          # Output formatting
├── lib/                 # Shared utilities
├── migrations/          # Version migrations
└── ...                  # Other optional directories
```

## Key Rules

1. **`default.nix`**: ONLY imports, NO `config = { ... }` blocks
2. **`options.nix`**: ONLY option definitions, NO implementation
3. **`config.nix`**: ALL implementation (symlink management, system config)
4. **Versioning**: ALL modules must have `_version` in `options.nix`
5. **Symlink Management**: Always in `config.nix`, runs even when disabled

## Template Compliance

This template follows all rules from `MODULE_TEMPLATE.md`:
- ✅ `default.nix` has NO `config` blocks
- ✅ `options.nix` has NO implementation
- ✅ `config.nix` has ALL implementation
- ✅ Versioning included
- ✅ Symlink management included
- ✅ Generic directory names used

## See Also

- `MODULE_TEMPLATE.md` - Complete template documentation and development guide
- `../Architecture.md` - System architecture and module structure (includes domain definitions)
- `../../nixos/core/desktop/` - Real core module example
- `../../nixos/core/management/logging/` - Real core module example (moved from features)
- `../../nixos/features/system/lock/` - Real feature module example (renamed from system-discovery)
