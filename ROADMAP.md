# 🗺️ NixOS Control Center - Roadmap

## 🎯 Central Config Path Management in Module Manager

### Overview
Individual modules should **no longer decide themselves** where their config paths are located. Instead, the **Module Manager becomes centrally responsible** for managing all config paths. This enables flexible folder structures (e.g., by user, environment, etc.) without changes to individual modules.

### Why this change?
- **Current**: Each module defines hardcoded: `configFile = "/etc/nixos/configs/${name}-config.nix"`
- **Problem**: No flexibility for later structuring (user separation, multi-host, etc.)
- **Goal**: Module Manager as central authority for config organization

---

## 🔍 Analysis: System-wide vs. User-specific Modules

### Current Structure Problem
**All modules** are currently under `core/system/` and have configs in `/etc/nixos/configs/${module}-config.nix`. But not all modules affect all users equally!

### Module Classification

**System-wide (affect all users equally):**
- `audio/` - Audio system is the same for all users
- `boot/` - Bootloader is system-wide
- `desktop/` - Desktop environment is the same for all users (with some user-specific possibilities)
- `hardware/` - Hardware configuration is system-wide
- `localization/` - Language/timezone is the same for all users
- `network/` - Network configuration is system-wide

**Potentially User-specific:**
- `packages/` - Different users might want different packages (**but see Home Manager note below**)
- `user/` - User management could have user-specific settings

### Important: Package Management Clarification

**Keep `packages/` as "shared" module** (don't rename it!) but clarify the architecture:

- **System Packages** (`environment.systemPackages`): What `packages/` module manages
- **User Packages**: Should go through **Home Manager** integration, NOT through duplicating the packages module

**Why?**
- Avoids confusion between system-wide vs. user-specific package management
- Follows NixOS best practices: system packages system-wide, user packages via Home Manager
- Clear separation: `packages/` = system foundation, Home Manager = user personalization

**Recommendation:** Keep `packages` as shared module for now, but document that user-specific packages should use Home Manager.

**Management/Infrastructure (system-wide):**
- `checks/`, `logging/`, `module-manager/`, etc. - System management

### Desktop Module Analysis: System vs. User Aspects

**System-wide components (must be consistent):**
- **Display Manager**: `sddm`, `gdm`, `lightdm` - only one can run system-wide
- **Base Services**: `dbus`, `xwayland` - must be available system-wide
- **GPU Drivers**: Hardware-dependent, affects all users

**Potentially user-specific aspects:**
- **Display Server**: Wayland vs X11 (GPU-dependent but user preference)
  - Modern GPUs (AMD, Intel) → prefer Wayland
  - Older NVIDIA → often still need X11 (Wayland support came later)
  - Some apps only work under X11
- **Theme Settings**: Dark/light theme could be user preference
- **Keyboard Layout**: Could be user-specific in multi-language households

**Current Reality:**
Desktop module remains **mostly system-wide** due to hardware dependencies and display manager constraints. User-specific customizations happen through:
- Personal dotfiles (`.config/plasma/`, `.gtkrc`, etc.)
- Home Manager for user-specific themes/shortcuts
- Login session selection at login

### New Structure Decision: Modern Categorization with Module Metadata

**Modern Folder Structure (adapted to your systemType approach):**
- **Personal Configs** → `/etc/nixos/configs/users/${user}/${module}-config.nix` (your overrides)
- **System Configs** → `/etc/nixos/configs/system/${module}-config.nix` (systemType-based)
- **Shared Configs** → `/etc/nixos/configs/shared/${module}-config.nix` (optional fallback)

**Module Manager decides centrally:**
```nix
# In module-manager-config.nix
{
  core.management.module-manager = {
    # Module categorization (can be overridden)
    moduleCategories = {
      system = ["audio" "desktop" "network" "hardware" "localization" "boot"];
      shared = ["packages"]; # can be system-wide + user-specific
      user = []; # purely user-specific modules (none yet)
    };

    # Separate configs for these users
    managedUsers = ["fr4iser"];

    # Path strategy
    configPathStrategy = "categorized"; # "flat", "categorized", "by-user"

    # NEW: Advanced options
    enableCaching = true;              # Cache path resolution for performance
    enableGitIntegration = false;      # Auto-commit config changes
    enableValidation = true;           # Schema validation for configs
  };
}
```

#### Module Metadata System (NEW)
Each module defines its own metadata instead of hardcoded categories:

```nix
# Example: modules define their own metadata
{
  name = "audio";
  description = "Audio system configuration";
  defaultCategory = "system";         # system | shared | user
  allowedCategories = ["system"];     # validation constraint
  supportsUserConfig = false;         # true if per-user configs make sense
  version = "1.0";
}
```

**Resulting modern structure:**
```
/etc/nixos/configs/
├── system/
│   ├── audio-config.nix          # system-wide
│   ├── desktop-config.nix        # system-wide
│   ├── network-config.nix        # system-wide
│   └── hardware-config.nix       # system-wide
├── shared/
│   └── packages-config.nix       # system packages (fallback)
└── users/
    └── fr4iser/
        ├── packages-config.nix   # user-specific packages (if needed)
        └── home-manager.nix      # Example: Home Manager config file (not implemented yet)
```

**Package Management Approach:**
- `packages/` stays as **shared module** (don't rename!)
- **System packages**: `packages/` manages `environment.systemPackages`
- **User packages**: Use **Home Manager** integration instead of duplicating package logic
- Clear separation: System foundation vs. User personalization

**Note on `home-manager.nix`:**
This is just an **example filename** for the future structure. Home Manager integration would create user-specific config files in the `users/${user}/` directory, separate from system configs.

**Advantages:**
- **Clear categorization**: system/ vs users/ vs shared/
- **Modern standards**: Similar to `/etc/systemd/`, `/home/user/.config/`
- **Extensible**: Easy to add new categories
- **Clear overview**: Quickly identify what's system-wide vs. user-specific

## 📋 Implementation Roadmap

### Phase 1: Foundations (1-2 days)

#### 1.1 Central Config Path Configuration
**File**: `nixos/core/management/module-manager/module-manager-config.nix`
- New option: `configPathStrategy` (enum: "flat", "by-type", "by-user", "by-category")
- New option: `baseConfigPath` (default: "/etc/nixos/configs")
- New option: `userSpecificModules` (list of modules that are user-specific)
- New option: `managedUsers` (list of users for which separate configs are created)

```nix
{
  core.management.module-manager = {
    configPathStrategy = "categorized"; # "flat", "categorized", "by-user", "by-category"
    baseConfigPath = "/etc/nixos/configs";
    userSpecificModules = ["packages"]; # only explicitly user-specific modules
    managedUsers = ["fr4iser"];
  };
}
```

#### 1.2 Config Path Resolver Function
**File**: `nixos/core/management/module-manager/lib/default.nix`
- New function: `resolveConfigPath(moduleName, category, user?)`
- Implementation of different strategies:
  - `flat`: `/etc/nixos/configs/${moduleName}-config.nix` (current standard)
  - `categorized`: System→`system/`, Shared→`shared/`, User→`users/${user}/`
  - `by-user`: All modules get user-specific configs
  - `by-category`: `/etc/nixos/configs/${category}/${moduleName}-config.nix`

**Resolution Precedence (Order of Precedence):**
When multiple config files exist for the same module, resolve in this order:

1. `users/${user}/${module}-config.nix` (highest priority when user active)
2. `hostname/${hostname}/${module}-config.nix` (for multi-host setups)
3. `environment/${environment}/${module}-config.nix` (dev/staging/prod)
4. `shared/${module}-config.nix` (shared fallback)
5. `system/${module}-config.nix` (system default)
6. `${module}-config.nix` (legacy fallback)

**Categorized strategy (recommended):**
```nix
# Enhanced pseudo-code with precedence and caching
resolveConfigPath = moduleName: attrs: let
  basePath = cfg.baseConfigPath;
  user = attrs.user or null;
  hostname = attrs.hostname or null;
  environment = attrs.environment or null;

  # Check existence in precedence order
  candidates = [
    (if user != null then "${basePath}/users/${user}/${moduleName}-config.nix" else null)
    (if hostname != null then "${basePath}/hostname/${hostname}/${moduleName}-config.nix" else null)
    (if environment != null then "${basePath}/environment/${environment}/${moduleName}-config.nix" else null)
    "${basePath}/shared/${moduleName}-config.nix"
    "${basePath}/system/${moduleName}-config.nix"
    "${basePath}/${moduleName}-config.nix" # fallback
  ];

  # Return first existing path (with caching if enabled)
  existingCandidates = lib.filter (path: path != null && builtins.pathExists path) candidates;
in
  if existingCandidates != [] then lib.head existingCandidates
  else lib.head candidates; # fallback to primary candidate
```

**Performance & Caching:**
- Optional in-memory caching during `nixos-rebuild`
- Cache invalidation when `managedUsers`/`moduleCategories` change
- Prevents redundant path resolution calculations

### Phase 2: Module Discovery Refactor (2-3 days)

#### 2.1 Extend Module Definition
**File**: `nixos/core/management/module-manager/lib/default.nix`
- Remove hardcoded `configFile` from `discoverModulesInDir`
- Add `configPathStrategy` and `baseConfigPath` from module manager config
- Module structure becomes:
```nix
{
  name = "audio";
  category = "system";
  description = "Audio system configuration";
  # NO configFile anymore - resolved dynamically
}
```

#### 2.2 Dynamic Config Path Resolution
- Integrate `resolveConfigPath` function
- Fallback mechanisms for different strategies
- Support migration of existing configs

### Phase 3: Update Mechanisms Adaptation (2-3 days)

#### 3.1 Update update-module-config Script
**File**: `nixos/core/management/module-manager/lib/default.nix`
- Remove hardcoded path logic
- Use `resolveConfigPath` for dynamic path resolution
- Support different config strategies

#### 3.2 Extend Config Helpers
**File**: `nixos/core/management/module-manager/lib/config-helpers.nix`
- `createModuleConfig` now accepts `configPathResolver`
- Automatic folder creation for new structures
- Migration from old to new paths

### Phase 4: Implement New Config Strategies (3-4 days)

#### 4.1 Implement Categorized Structure
- System modules under `/etc/nixos/configs/system/`
- Shared modules under `/etc/nixos/configs/shared/` (fallback) and `/etc/nixos/configs/users/${user}/`
- User modules under `/etc/nixos/configs/users/${user}/`
- Automatic folder creation and migration

#### 4.2 Category-based Organization
- Structure: `/etc/nixos/configs/${category}/${module}-config.nix`
- Example: `/etc/nixos/configs/system/audio-config.nix`

#### 4.3 Extend Existing Migration System
- **Leverage existing system**: Use the sophisticated migration system already in codebase
- **Extend for categories**: Make migration place configs in system/, shared/, users/ based on module metadata
- **Create v1→v2 migration**: Add new schema version for categorized structure
- **Maintain compatibility**: Existing migration features (atomic, backup, validation) remain

```bash
# Existing migration system (already implemented!)
sudo ncc-config-check    # Validates + migrates automatically
sudo ncc-migrate-config  # Manual migration
ncc-detect-version       # Shows current config version
```

### Phase 5: Testing & Documentation (2-3 days)

#### 5.1 Comprehensive Testing
- **Unit Tests**: `resolveConfigPath` for all strategies + precedence rules
- **Integration Tests**: Multi-user, hostname, environment combinations
- **Migration Tests**: Backup, apply, rollback with fixture configs
- **Permission Tests**: Correct ownership of directories/files
- **CI Integration**: Automated linting + validation in Nix builds

#### 5.2 Enhanced CLI/UX
```bash
# New useful commands
module-manager list --strategy=categorized              # Show resolved paths
module-manager create-config audio --for-user=fr4iser  # Create template
module-manager validate /etc/nixos/configs/            # Schema validation
module-manager diff module audio                       # Show path differences
module-manager set-strategy categorized --apply        # Change strategy
```

#### 5.3 Update Documentation
- `docs/02_architecture/Architecture.md` - New config architecture
- `docs/02_architecture/example_module/MODULE_TEMPLATE.md` - Module metadata guide
- CLI documentation for new options
- Migration guide with examples

---

## 🔄 Migration Strategy

### Immediate Migration (Breaking Change)
1. **Backup all configs**: `cp -r /etc/nixos/configs /etc/nixos/configs.backup.$(date +%s)`
2. **Deploy new module manager version**
3. **Run migration script** (moves configs to new paths)
4. **System rebuild** with new structure

### Alternative: Gradual Migration
1. **Maintain backward compatibility** (old paths still work)
2. **Activate new strategies** optionally
3. **Gradual migration** module by module

---

## 🚀 Future Extensions

### Extended Config Strategies
- **Multi-Host**: `/etc/nixos/configs/${hostname}/`
- **Environment-based**: `/etc/nixos/configs/${environment}/` (dev/staging/prod)
- **Hybrid**: Combination of different strategies

### Extended Features
- **Config Sharing**: Shared configs for similar modules
- **Config Versioning**: Automatic backups and versioning
- **Config Sync**: Synchronization between different hosts

### Integration with Other Systems
- **Home Manager Integration**: Auto-sync user configs + generate stubs
- **Git Integration**: Version control configs with auto-commit hooks
- **Backup System**: Automatic config backups + deployment commands
- **Multi-Host Support**: hostname-specific configs
- **Environment Support**: dev/staging/prod config separation

---

## ⚠️ Risks & Mitigation

### Breaking Changes
- **Risk**: Existing setups no longer work
- **Mitigation**: Comprehensive migration scripts, rollback options

### Complexity
- **Risk**: New logic too complex for maintenance
- **Mitigation**: Clear abstractions, comprehensive tests

### Performance
- **Risk**: Path resolution slows down system
- **Mitigation**: Caching, optimization of resolver functions

### Edge Cases & Additional Risks

#### Multiple Users with Package Conflicts
- **Risk**: Duplicate packages, version conflicts when users have different package configs
- **Mitigation**: Strongly recommend Home Manager for user packages; document merge strategies if user-level packages allowed

#### Hardware-Specific Configurations (NVIDIA/Wayland)
- **Risk**: Desktop configs break on different hardware
- **Mitigation**: Keep desktop system-wide; allow user preferences only for themes/GUI elements

#### Permission & Security
- **Risk**: Incorrect file permissions on migrated configs
- **Mitigation**: Set proper ownership (root:root, 755/644); validate permissions in migration

#### Flakes vs Non-Flakes Compatibility
- **Risk**: Different deployment methods (flakes vs traditional)
- **Mitigation**: Support both; add flake-aware migration options

---

## 📅 Timeline

| Phase | Duration | Milestones |
|-------|----------|------------|
| Phase 1 | 1-2 days | Foundations implemented |
| Phase 2 | 2-3 days | Module discovery refactored |
| Phase 3 | 2-3 days | Update mechanisms adapted |
| Phase 4 | 3-4 days | New strategies implemented |
| Phase 5 | 2-3 days | Tested & documented |

**Total**: ~10-15 days for complete implementation

---

## ✅ Success Criteria

- [ ] Modules **NO LONGER** define config paths themselves
- [ ] Module Manager decides **centrally** about all config paths
- [ ] Different config strategies work (`flat`, `by-user`, `by-category`)
- [ ] Migration of existing setups works smoothly
- [ ] Backward compatibility for critical cases
- [ ] Comprehensive tests for all path strategies
- [ ] Documentation is current and complete
