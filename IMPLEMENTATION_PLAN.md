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
# Note: desktop/ and audio/ remain directly under core/ (no domain grouping)
```

### Step 1.2: Create Feature Domain Directories

```bash
# Create all Feature domain directories
mkdir -p nixos/features/system
mkdir -p nixos/features/infrastructure
mkdir -p nixos/features/security
mkdir -p nixos/features/specialized
```

## Phase 2: Module Migration (Mapping)

### Core Module Mapping (Current → New)

| Current | New | Domain | Action | Priority |
|---------|-----|--------|--------|----------|
| `core/boot/` | `core/system/boot/` | system | Move | High |
| `core/hardware/` | `core/system/hardware/` | system | Move | High |
| `core/network/` | `core/system/network/` | system | Move | High |
| `core/user/` | `core/system/user/` | system | Move | High |
| `core/localization/` | `core/system/localization/` | system | Move | High |
| `core/desktop/` | `core/desktop/` | - | Keep (no domain) | High |
| `core/audio/` | `core/audio/` | - | Keep (no domain) | High |
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

6. **`core/desktop/`** (stays)
   - [ ] Has `default.nix` (only imports)
   - [ ] Has `options.nix` with `_version`
   - [ ] Has `config.nix` with symlink management
   - [ ] Has `user-configs/desktop-config.nix`

7. **`core/audio/`** (stays)
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

## Phase 5: Implementation Order

### Step 5.1: Preparation
1. Create backup branch: `git checkout -b backup-before-domain-migration`
2. Commit current state
3. Create new branch: `git checkout -b domain-structure-migration`

### Step 5.2: Core Modules (Priority: High)
**Order:**
1. Create domain directories (Step 1.1)
2. Move system domain modules (boot, hardware, network, user, localization)
3. Move infrastructure domain modules (cli-formatter, command-center, config)
4. Move management domain modules (system-checks → checks, system-logger → logging)
5. Update `core/default.nix` imports
6. Test: `nixos-rebuild dry-run`

### Step 5.3: System-Manager Split (Priority: Critical)
**Order:**
1. Create new module structures (Step 3.1)
2. Create `module-manager/` module files (default.nix, options.nix, config.nix, commands.nix)
3. Move handlers to module-manager
4. Move rest of system-manager to management/system-manager
5. Update all import paths
6. Test: `nixos-rebuild dry-run`

### Step 5.4: Feature Modules (Priority: Medium)
**Order:**
1. Create domain directories (Step 1.2)
2. Move system domain features (system-discovery → system/lock)
3. Move infrastructure domain features (homelab, vm, bootentry)
4. Move security domain features (ssh-client, ssh-server)
5. Move specialized domain features (ai-workspace, hackathon)
6. Update `features/default.nix` (if needed for auto-discovery)
7. Update `features/metadata.nix` (if feature names changed)
8. Test: `nixos-rebuild dry-run`

### Step 5.5: Template Compliance Check
**For each module:**
1. Check `default.nix` (only imports)
2. Check `options.nix` (has `_version`)
3. Check `config.nix` (has symlink management)
4. Check `user-configs/` (exists and has config file)
5. If non-compliant: Create `TODO.md` in module directory

### Step 5.6: Update Import Paths Globally
**Files to update:**
1. `nixos/flake.nix` - Update all module import paths
2. `nixos/core/default.nix` - Update core module imports
3. `nixos/features/default.nix` - Update if needed (auto-discovery should handle it)
4. All files that reference old paths (use grep to find)

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

