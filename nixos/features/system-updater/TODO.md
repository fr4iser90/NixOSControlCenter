# TODO: Refactor system-updater to match Template Structure

This document tracks all changes needed to refactor `system-updater` to match the template structure defined in `.TEMPLATE/README.md`.

## Current Structure Analysis

### ✅ Already Present
- `default.nix` - ✅ Exists (main entry point)
- Multiple files: `update.nix`, `feature-manager.nix`, `channel-manager.nix`, `config-migration.nix`, `config-validator.nix`, `desktop-manager.nix`, `homelab-utils.nix`

### ❌ Needs Refactoring

#### 1. **File Organization**

**Current State:**
- Files in root: `update.nix`, `feature-manager.nix`, `channel-manager.nix`, etc.
- No clear organization

**Target State:**
- Organize files by function
- Move to appropriate directories

**Files to organize:**
- `update.nix` → Could be `handlers/update.nix` or `scripts/update.nix`
- `feature-manager.nix` → Could be `handlers/feature-manager.nix`
- `channel-manager.nix` → Could be `handlers/channel-manager.nix`
- `config-migration.nix` → Could be `migrations/config-migration.nix` (but this is for system config, not feature)
- `config-validator.nix` → Could be `validators/config-validator.nix`
- `desktop-manager.nix` → Could be `handlers/desktop-manager.nix`
- `homelab-utils.nix` → Could be `lib/homelab-utils.nix`

#### 2. **Core Files Missing**

**Current State:**
- No `README.md`
- No `options.nix` (options likely in `default.nix`)
- No `commands.nix` (commands likely registered inline)

**Target State:**
- Create all core files according to template

**Files to create:**
- `README.md` - Feature documentation
- `options.nix` - Configuration options
- `commands.nix` - Command registration
- `lib/` - For utilities

#### 3. **Versioning**

**Current State:**
- No versioning implemented

**Target State:**
- Add `featureVersion = "1.0"` in `options.nix`
- Add `_version` option (internal)

**Files to create/update:**
- `options.nix` - Add versioning

#### 4. **New Functionality: Feature Version Checker**

**Current State:**
- System Updater needs new functionality for feature version checking

**Target State:**
- Create `feature-version-check.nix` (Phase 2 from main TODO)
- Create `smart-update.nix` (Phase 3 from main TODO)

**Files to create:**
- `handlers/feature-version-check.nix` - Version checking logic
- `handlers/smart-update.nix` - Smart update logic
- `scripts/check-versions.nix` - Command: `ncc check-feature-versions`
- `scripts/smart-update.nix` - Command: `ncc update-features`

## Refactoring Steps

### Step 1: Create Core Files
- [ ] Create `README.md` with feature documentation
- [ ] Create `options.nix` - Extract all options from `default.nix`
- [ ] Add `featureVersion = "1.0"` to `options.nix`
- [ ] Add `_version` option to `options.nix`
- [ ] Create `commands.nix` - Move command registration from `default.nix`
- [ ] Create `lib/default.nix` - Export utilities

### Step 2: Reorganize Files
- [ ] Create `handlers/` directory
- [ ] Create `lib/` directory
- [ ] Move `update.nix` → `handlers/update.nix` (or appropriate)
- [ ] Move `feature-manager.nix` → `handlers/feature-manager.nix`
- [ ] Move `channel-manager.nix` → `handlers/channel-manager.nix`
- [ ] Move `desktop-manager.nix` → `handlers/desktop-manager.nix`
- [ ] Move `homelab-utils.nix` → `lib/homelab-utils.nix`
- [ ] Review `config-migration.nix` and `config-validator.nix` - these might be for system config, not feature

### Step 3: Add Feature Version Checking (Phase 2)
- [ ] Create `handlers/feature-version-check.nix`
- [ ] Create `scripts/check-versions.nix`
- [ ] Register `ncc check-feature-versions` command

### Step 4: Add Smart Update (Phase 3)
- [ ] Create `handlers/smart-update.nix`
- [ ] Create `scripts/smart-update.nix`
- [ ] Register `ncc update-features` command

### Step 5: Update default.nix
- [ ] Remove option definitions
- [ ] Import `options.nix`
- [ ] Import `commands.nix`
- [ ] Add enable mapping pattern
- [ ] Use `mkMerge` for config

### Step 6: Testing
- [ ] Test: `nixos-rebuild dry-run` works
- [ ] Test: All commands work
- [ ] Test: Feature enables/disables correctly

## Priority Order

1. **HIGH**: Add versioning (required for System Updater)
2. **HIGH**: Create `options.nix` (template compliance)
3. **HIGH**: Create `commands.nix` (template compliance)
4. **HIGH**: Add feature version checking (Phase 2 from main TODO)
5. **MEDIUM**: Reorganize files (better structure)
6. **MEDIUM**: Create `README.md` (documentation)

## Notes

- This feature is critical for the versioning system
- Needs to be refactored first to support other features
- `config-migration.nix` and `config-validator.nix` might be for system config (central), not feature-specific

