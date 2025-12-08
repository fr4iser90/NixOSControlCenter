# Implementation Plan: Domain Structure & Template Compliance

## Overview

This plan outlines the complete migration to domain-driven module structure and ensures all modules comply with the template requirements.

## Phase 1: Create Domain Structure

### Step 1.1: Create Core Domain Directories

```bash
# Create all Core domain directories
mkdir -p nixos/core/system
mkdir -p nixos/core/infrastructure
mkdir -p nixos/core/module-management
mkdir -p nixos/core/management
# Note: ALL modules are domain-grouped, including desktop/ and audio/ → system/
```

### Step 1.2: Create Feature Domain Directories

```bash
# Create all Feature domain directories
mkdir -p nixos/features/system
mkdir -p nixos/features/infrastructure
mkdir -p nixos/features/security
mkdir -p nixos/features/specialized
```

## Phase 1.5: Naming Conventions

### Module Naming

**Module Directory Names:**
- Use **kebab-case** (lowercase with hyphens)
- Examples: `system-lock`, `vm-manager`, `ssh-client`, `boot-entry`
- No underscores, no camelCase, no PascalCase

**Module Path Structure:**
- Core: `nixos/core/<domain>/<module-name>/`
- Features: `nixos/features/<domain>/<module-name>/`

### Option Path Conventions

**Core Modules:**
```nix
# Pattern: options.systemConfig.<domain>.<module>
options.systemConfig.system.boot = { ... }
options.systemConfig.system.hardware = { ... }
options.systemConfig.system.desktop = { ... }
options.systemConfig.infrastructure.cli-formatter = { ... }
options.systemConfig.management.system-manager = { ... }
```

**Feature Modules:**
```nix
# Pattern: options.features.<domain>.<module>
options.features.system.lock = { ... }
options.features.infrastructure.vm = { ... }
options.features.security.ssh-client = { ... }
options.features.specialized.ai-workspace = { ... }
```

**Important:** After domain migration, ALL option paths must include the domain!

### Config Access Conventions

**In `default.nix` and `config.nix`:**
```nix
# Core modules
let
  cfg = systemConfig.system.boot or {};  # With domain
  # NOT: systemConfig.boot
in { ... }

# Feature modules
let
  cfg = systemConfig.features.system.lock or {};  # With domain
  # NOT: systemConfig.features.lock
in { ... }
```

### Config File Naming

**User Config Files:**
- Pattern: `<module-name>-config.nix`
- Location: `user-configs/<module-name>-config.nix`
- Symlink: `/etc/nixos/configs/<module-name>-config.nix`
- Examples:
  - `desktop-config.nix`
  - `vm-config.nix`
  - `ssh-client-config.nix`
  - `lock-config.nix` (not `system-lock-config.nix` - use module name without domain)

**Note:** Config file names use the module name (without domain prefix).

### Directory Naming

**Module Directories:**
- Use **kebab-case**: `system-lock`, `vm-manager`, `ssh-client`
- No underscores: ❌ `system_lock`, ✅ `system-lock`
- No camelCase: ❌ `vmManager`, ✅ `vm-manager`

**Sub-Directories (Generic vs Semantic):**
- Prefer **generic names**: `handlers/`, `collectors/`, `processors/`, `validators/`
- Use **semantic names** only when concept is central: `scanners/`, `providers/`, `drivers/`
- See `MODULE_TEMPLATE.md` Section 8 for details

### File Naming

**Standard Files:**
- `default.nix` - Module entry point
- `options.nix` - Option definitions
- `config.nix` - Implementation
- `commands.nix` - Command registration
- `types.nix` - Custom types
- `systemd.nix` - Systemd services

**Sub-Module Files:**
- Use **kebab-case**: `feature-manager.nix`, `system-update.nix`
- Descriptive names: `config-loader.nix`, `backup-helpers.nix`

### Import Path Conventions

**After Domain Migration:**
```nix
# Core modules
imports = [
  ./core/system/boot
  ./core/system/hardware
  ./core/infrastructure/cli-formatter
  ./core/management/system-manager
];

# Feature modules (auto-discovery handles paths)
# But manual imports would be:
imports = [
  ./features/system/lock
  ./features/infrastructure/vm
  ./features/security/ssh-client
];
```

### Version Naming

**Module Version:**
- Pattern: `"X.Y"` (semantic versioning, major.minor)
- Example: `"1.0"`, `"1.1"`, `"2.0"`
- Defined in `options.nix`:
  ```nix
  _version = lib.mkOption {
    type = lib.types.str;
    default = "1.0";
    internal = true;
  };
  ```

**Migration Files:**
- Pattern: `v<from>-to-v<to>.nix`
- Examples: `v1.0-to-v1.1.nix`, `v1.0-to-v2.0.nix`

### Summary Table

| Element | Convention | Example |
|---------|------------|---------|
| Module directory | kebab-case | `system-lock`, `vm-manager` |
| Core option path | `systemConfig.<domain>.<module>` | `systemConfig.system.boot` |
| Feature option path | `features.<domain>.<module>` | `features.system.lock` |
| Config file | `<module-name>-config.nix` | `desktop-config.nix` |
| Config access (Core) | `systemConfig.<domain>.<module>` | `systemConfig.system.desktop` |
| Config access (Feature) | `systemConfig.features.<domain>.<module>` | `systemConfig.features.system.lock` |
| Import path (Core) | `./core/<domain>/<module>` | `./core/system/boot` |
| Import path (Feature) | `./features/<domain>/<module>` | `./features/system/lock` |
| Version | `"X.Y"` | `"1.0"` |
| Migration file | `v<from>-to-v<to>.nix` | `v1.0-to-v2.0.nix` |

## Phase 2: Module Migration (Mapping)

### Core Module Mapping (Current → New)

| Current | New | Domain | Action | Priority |
|---------|-----|--------|--------|----------|
| `core/boot/` | `core/system/boot/` | system | Move | High |
| `core/hardware/` | `core/system/hardware/` | system | Move | High |
| `core/network/` | `core/system/network/` | system | Move | High |
| `core/user/` | `core/system/user/` | system | Move | High |
| `core/localization/` | `core/system/localization/` | system | Move | High |
| `core/desktop/` | `core/system/desktop/` | system | Move | High |
| `core/audio/` | `core/system/audio/` | system | Move | High |
| `core/cli-formatter/` | `core/infrastructure/cli-formatter/` | infrastructure | Move | High |
| `core/command-center/` | `core/infrastructure/command-center/` | infrastructure | Move | High |
| `core/config/` | `core/infrastructure/config/` | infrastructure | Move | High |
| `core/system-manager/` | **SPLIT** | - | See Phase 3 | Critical |
| `features/system-checks/` | `core/management/checks/` | management | Move | High |
| `features/system-logger/` | `core/management/logging/` | management | Move | High |

### Feature Module Mapping (Current → New)

| Current | New | Domain | Action | Priority |
|---------|-----|--------|--------|----------|
| `features/system-discovery/` | `features/system/lock/` | system | Move + Rename | Medium |
| `features/homelab-manager/` | `features/infrastructure/homelab/` | infrastructure | Move + Rename | Medium |
| `features/vm-manager/` | `features/infrastructure/vm/` | infrastructure | Move + Rename | Medium |
| `features/bootentry-manager/` | `features/infrastructure/bootentry/` | infrastructure | Move + Rename | Medium |
| `features/ssh-client-manager/` | `features/security/ssh-client/` | security | Move + Rename | Medium |
| `features/ssh-server-manager/` | `features/security/ssh-server/` | security | Move + Rename | Medium |
| `features/ai-workspace/` | `features/specialized/ai-workspace/` | specialized | Move | Medium |
| `features/hackathon-manager/` | `features/specialized/hackathon/` | specialized | Move + Rename | Medium |

## Phase 3: System-Manager Split (Critical)

### Current Structure Analysis

**Current:** `core/system-manager/`
- Contains: Feature management, version checking, system updates, channel management, desktop management
- Handlers:
  - `feature-manager.nix` → Module Management (Feature Enable/Disable)
  - `module-version-check.nix` → Module Management (Version Checking)
  - `system-update.nix` → System Management (System Updates)
  - `channel-manager.nix` → System Management (Channel Management)
  - `desktop-manager.nix` → System Management (Desktop Management)

### Split Strategy

#### Step 3.1: Create New Module Structures

```bash
# Create module-management module
mkdir -p nixos/core/module-management/module-manager/{handlers,lib,user-configs}

# Create new system-manager location
mkdir -p nixos/core/management/system-manager/{handlers,scripts,lib,validators,user-configs}
```

#### Step 3.2: Split System-Manager Components

**Module Management Domain (`core/module-management/module-manager/`):**
- Purpose: Module lifecycle, registration, and versioning
- Components to move:
  - `core/system-manager/handlers/feature-manager.nix` → `core/module-management/module-manager/handlers/feature-manager.nix`
  - `core/system-manager/handlers/module-version-check.nix` → `core/module-management/module-manager/handlers/module-version-check.nix`
  - `core/system-manager/lib/module-registry.nix` (if exists) → `core/module-management/module-manager/lib/module-registry.nix`
- New files needed:
  - `default.nix` (ONLY imports)
  - `options.nix` (with `_version`)
  - `config.nix` (ALL implementation)
  - `commands.nix` (if CLI commands needed)
  - `user-configs/module-manager-config.nix`

**System Management Domain (`core/management/system-manager/`):**
- Purpose: System operations, updates, configuration
- Components to move:
  - `core/system-manager/` (everything else) → `core/management/system-manager/`
  - Keep: `system-update.nix`, `channel-manager.nix`, `desktop-manager.nix` in handlers/
  - Keep: `scripts/`, `lib/`, `validators/`
- Update files:
  - `default.nix` (update imports)
  - `options.nix` (update option paths)
  - `config.nix` (update config paths)
  - `commands.nix` (update command paths)

#### Step 3.3: Update Import Paths

**Files to update:**
1. `nixos/core/default.nix`:
   ```nix
   imports = [
     # ... other imports
     ./module-management/module-manager
     ./management/system-manager
   ];
   ```

2. `nixos/flake.nix`:
   - Update `configLoader` path if it references system-manager
   - Update any other references to system-manager paths

3. All files that import from `core/system-manager/`:
   - Search for: `import.*system-manager`
   - Update to new paths

## Phase 4: Template Compliance Check

### Template Compliance Requirements

**REQUIRED for ALL modules:**
1. ✅ **`default.nix`** - ONLY imports, NO `config = { ... }` blocks
2. ✅ **`options.nix`** - ALL option definitions with `_version` option
3. ✅ **`config.nix`** - ALL implementation (symlink management, system config)
4. ✅ **`user-configs/`** - Directory with user config file(s)

**OPTIONAL (only when needed):**
- 📝 **`commands.nix`** - Command registration (features with CLI)
- 📝 **`types.nix`** - Custom types
- 📝 **`systemd.nix`** - Systemd services/timers
- 📝 **`migrations/`** - Version migrations

### Compliance Check Process

For each module, verify:

#### 1. `default.nix` Check
```nix
# ❌ WRONG: Contains config block
{ ... }: {
  config = { ... };
}

# ✅ CORRECT: Only imports
{ ... }: {
  imports = [ ./options.nix ./config.nix ];
}
```

#### 2. `options.nix` Check
```nix
# ✅ MUST contain for Core modules:
options.systemConfig.<domain>.<module>._version = lib.mkOption {
  type = lib.types.str;
  default = "1.0";
  internal = true;
};

# ✅ MUST contain for Feature modules:
options.features.<domain>.<module>._version = lib.mkOption {
  type = lib.types.str;
  default = "1.0";
  internal = true;
};
```

#### 3. `config.nix` Check
```nix
# ✅ MUST contain: Symlink management
system.activationScripts.<module>-config-symlink = ''
  # Symlink management code
'';
```

#### 4. `user-configs/` Check
- Directory must exist
- File: `<module-name>-config.nix` must exist

### Module-by-Module Compliance Check

#### Core Modules to Check:

1. **`core/system/boot/`** (after move)
   - [ ] Has `default.nix` (only imports)
   - [ ] Has `options.nix` with `_version`
   - [ ] Has `config.nix` with symlink management
   - [ ] Has `user-configs/boot-config.nix`

2. **`core/system/hardware/`** (after move)
   - [ ] Has `default.nix` (only imports)
   - [ ] Has `options.nix` with `_version`
   - [ ] Has `config.nix` with symlink management
   - [ ] Has `user-configs/hardware-config.nix`

3. **`core/system/network/`** (after move)
   - [ ] Has `default.nix` (only imports)
   - [ ] Has `options.nix` with `_version`
   - [ ] Has `config.nix` with symlink management
   - [ ] Has `user-configs/network-config.nix`

4. **`core/system/user/`** (after move)
   - [ ] Has `default.nix` (only imports)
   - [ ] Has `options.nix` with `_version`
   - [ ] Has `config.nix` with symlink management
   - [ ] Has `user-configs/user-config.nix`

5. **`core/system/localization/`** (after move)
   - [ ] Has `default.nix` (only imports)
   - [ ] Has `options.nix` with `_version`
   - [ ] Has `config.nix` with symlink management
   - [ ] Has `user-configs/localization-config.nix`

6. **`core/system/desktop/`** (after move)
   - [ ] Has `default.nix` (only imports)
   - [ ] Has `options.nix` with `_version`
   - [ ] Has `config.nix` with symlink management
   - [ ] Has `user-configs/desktop-config.nix`

7. **`core/system/audio/`** (after move)
   - [ ] Has `default.nix` (only imports)
   - [ ] Has `options.nix` with `_version`
   - [ ] Has `config.nix` with symlink management
   - [ ] Has `user-configs/audio-config.nix`

8. **`core/infrastructure/cli-formatter/`** (after move)
   - [ ] Has `default.nix` (only imports)
   - [ ] Has `options.nix` with `_version`
   - [ ] Has `config.nix` with symlink management
   - [ ] Has `user-configs/cli-formatter-config.nix`

9. **`core/infrastructure/command-center/`** (after move)
   - [ ] Has `default.nix` (only imports)
   - [ ] Has `options.nix` with `_version`
   - [ ] Has `config.nix` with symlink management
   - [ ] Has `user-configs/command-center-config.nix`

10. **`core/infrastructure/config/`** (after move)
    - [ ] Has `default.nix` (only imports)
    - [ ] Has `options.nix` with `_version`
    - [ ] Has `config.nix` with symlink management
    - [ ] Has `user-configs/config-config.nix`

11. **`core/module-management/module-manager/`** (NEW - after split)
    - [ ] Has `default.nix` (only imports)
    - [ ] Has `options.nix` with `_version`
    - [ ] Has `config.nix` with symlink management
    - [ ] Has `commands.nix` (if CLI commands)
    - [ ] Has `user-configs/module-manager-config.nix`
    - [ ] Has `handlers/feature-manager.nix`
    - [ ] Has `handlers/module-version-check.nix`

12. **`core/management/system-manager/`** (after split)
    - [ ] Has `default.nix` (only imports)
    - [ ] Has `options.nix` with `_version`
    - [ ] Has `config.nix` with symlink management
    - [ ] Has `commands.nix` (if CLI commands)
    - [ ] Has `user-configs/system-manager-config.nix`
    - [ ] Has `handlers/system-update.nix`
    - [ ] Has `handlers/channel-manager.nix`
    - [ ] Has `handlers/desktop-manager.nix`

13. **`core/management/checks/`** (after move from features)
    - [ ] Has `default.nix` (only imports)
    - [ ] Has `options.nix` with `_version`
    - [ ] Has `config.nix` with symlink management
    - [ ] Has `user-configs/checks-config.nix`

14. **`core/management/logging/`** (after move from features)
    - [ ] Has `default.nix` (only imports)
    - [ ] Has `options.nix` with `_version`
    - [ ] Has `config.nix` with symlink management
    - [ ] Has `user-configs/logging-config.nix`

#### Feature Modules to Check:

1. **`features/system/lock/`** (after move + rename from system-discovery)
   - [ ] Has `default.nix` (only imports)
   - [ ] Has `options.nix` with `_version`
   - [ ] Has `config.nix` with symlink management
   - [ ] Has `commands.nix` (CLI commands)
   - [ ] Has `user-configs/lock-config.nix`
   - [ ] Has `scripts/` (if CLI scripts)
   - [ ] Has `scanners/` (semantic name - OK for this feature)

2. **`features/infrastructure/homelab/`** (after move + rename)
   - [ ] Has `default.nix` (only imports)
   - [ ] Has `options.nix` with `_version`
   - [ ] Has `config.nix` with symlink management
   - [ ] Has `commands.nix` (CLI commands)
   - [ ] Has `user-configs/homelab-config.nix`
   - [ ] Has `lib/` (if utilities)

3. **`features/infrastructure/vm/`** (after move + rename)
   - [ ] Has `default.nix` (only imports)
   - [ ] Has `options.nix` with `_version`
   - [ ] Has `config.nix` with symlink management
   - [ ] Has `commands.nix` (CLI commands)
   - [ ] Has `user-configs/vm-config.nix`
   - [ ] Has `lib/` (if utilities)

4. **`features/infrastructure/bootentry/`** (after move + rename)
   - [ ] Has `default.nix` (only imports)
   - [ ] Has `options.nix` with `_version`
   - [ ] Has `config.nix` with symlink management
   - [ ] Has `commands.nix` (CLI commands)
   - [ ] Has `user-configs/bootentry-config.nix`
   - [ ] Has `providers/` (semantic name - OK for this feature)

5. **`features/security/ssh-client/`** (after move + rename)
   - [ ] Has `default.nix` (only imports)
   - [ ] Has `options.nix` with `_version`
   - [ ] Has `config.nix` with symlink management
   - [ ] Has `commands.nix` (CLI commands)
   - [ ] Has `user-configs/ssh-client-config.nix`
   - [ ] Has `scripts/` (if CLI scripts)

6. **`features/security/ssh-server/`** (after move + rename)
   - [ ] Has `default.nix` (only imports)
   - [ ] Has `options.nix` with `_version`
   - [ ] Has `config.nix` with symlink management
   - [ ] Has `commands.nix` (CLI commands)
   - [ ] Has `user-configs/ssh-server-config.nix`
   - [ ] Has `scripts/` (if CLI scripts)

7. **`features/specialized/ai-workspace/`** (after move)
   - [ ] Has `default.nix` (only imports)
   - [ ] Has `options.nix` with `_version`
   - [ ] Has `config.nix` with symlink management
   - [ ] Has `user-configs/ai-workspace-config.nix`
   - [ ] Has `containers/` (semantic name - OK for this feature)
   - [ ] Has `llm/` (semantic name - OK for this feature)
   - [ ] Has `services/` (semantic name - OK for this feature)

8. **`features/specialized/hackathon/`** (after move + rename)
   - [ ] Has `default.nix` (only imports)
   - [ ] Has `options.nix` with `_version`
   - [ ] Has `config.nix` with symlink management
   - [ ] Has `commands.nix` (CLI commands)
   - [ ] Has `user-configs/hackathon-config.nix`

## Phase 5: Implementation Order (Single Run)

### Step 5.1: Preparation
1. Create backup branch: `git checkout -b backup-before-domain-migration`
2. Commit current state
3. Create new branch: `git checkout -b domain-structure-migration`

### Step 5.2: Execute All Steps in One Run

**ALL steps below are executed in sequence WITHOUT testing between steps. Final test at the end.**

1. **Create all domain directories** (Phase 1.1 + 1.2)
2. **Move all Core modules** (Phase 2 - all at once)
3. **Move all Feature modules** (Phase 2 - all at once)
4. **System-Manager Split** (Phase 3 - complete)
5. **Update all import paths globally** (Phase 5.6 - all files)
6. **Template Compliance Check** (Phase 4 - create TODO.md for non-compliant)
7. **Final test**: `nixos-rebuild dry-run` (ONCE at the end)

**Important:** No intermediate testing. All changes are made, then tested once at the end.

## Phase 6: TODO.md Template for Non-Compliant Modules

For each non-compliant module, create `TODO.md`:

```markdown
# TODO: Template Compliance

## Status: ❌ Not Template-Compliant

## Missing/Faulty Components:

### ✅ Present:
- [x] `default.nix`
- [x] `options.nix`
- [x] `config.nix`
- [x] `user-configs/`

### ❌ Missing/Faulty:
- [ ] `_version` in `options.nix`
- [ ] Symlink management in `config.nix`
- [ ] `default.nix` contains `config = { ... }` block (should only have imports)

## To Do:

1. [ ] Clean up `default.nix` (only imports)
2. [ ] Add `_version` option in `options.nix`
3. [ ] Implement symlink management in `config.nix`
4. [ ] Create `user-configs/<module>-config.nix` (if missing)

## References:
- Template: `docs/02_architecture/example_module/`
- Documentation: `docs/02_architecture/example_module/MODULE_TEMPLATE.md`
- Architecture: `docs/02_architecture/Architecture.md`
```

## Phase 7: Verification Checklist

After completing all phases:

- [ ] All domain directories created
- [ ] All modules moved to correct locations
- [ ] System-manager split completed
- [ ] All import paths updated
- [ ] `nixos-rebuild dry-run` succeeds
- [ ] All modules checked for template compliance
- [ ] TODO.md created for non-compliant modules
- [ ] Git commits made after each major step
- [ ] Documentation updated (if needed)

## Important Notes

- **Do NOT do everything at once**: One module at a time
- **Git commits**: Commit after each successful module migration
- **Backup**: Create backup branch before starting
- **Test**: Run `nixos-rebuild dry-run` after each major change
- **Documentation**: Update Architecture.md if module structure changes significantly

## Quick Reference: Command Examples

```bash
# Move module
mv nixos/core/boot nixos/core/system/boot

# Update import in file
# Old: ./boot
# New: ./system/boot

# Check template compliance
grep -r "config = {" nixos/core/system/boot/default.nix
grep -r "_version" nixos/core/system/boot/options.nix
ls nixos/core/system/boot/user-configs/

# Test build
sudo nixos-rebuild dry-run
```

