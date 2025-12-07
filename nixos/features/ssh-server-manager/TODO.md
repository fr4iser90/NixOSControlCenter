# TODO: Refactor ssh-server-manager to match Template Structure

This document tracks all changes needed to refactor `ssh-server-manager` to match the template structure defined in `.TEMPLATE/README.md`.

## Current Structure Analysis

### ✅ Already Present
- `README.md` - ✅ Exists
- `default.nix` - ✅ Exists (main entry point)
- `scripts/` - ✅ Exists (commands: `approve-request.nix`, `grant-access.nix`, etc.)
- Files in root: `auth.nix`, `monitoring.nix`, `notifications.nix`

### ❌ Needs Refactoring

#### 1. **File Organization**

**Current State:**
- Files in root: `auth.nix`, `monitoring.nix`, `notifications.nix`
- Scripts in `scripts/` directory ✅

**Target State:**
- Move handlers to `handlers/` directory
- Organize by function

**Files to move:**
- `auth.nix` → `handlers/auth.nix` (or `validators/auth.nix` if it's validation)
- `monitoring.nix` → `monitors/monitoring.nix` (or `handlers/monitoring.nix`)
- `notifications.nix` → `notifiers/notifications.nix` (or `handlers/notifications.nix`)

#### 2. **Core Files Missing**

**Current State:**
- No `options.nix` (options likely in `default.nix`)
- No `commands.nix` (commands likely registered inline)

**Target State:**
- Create all core files according to template

**Files to create:**
- `options.nix` - Configuration options
- `commands.nix` - Command registration

#### 3. **Versioning**

**Current State:**
- No versioning implemented

**Target State:**
- Add `moduleVersion = "1.0"` in `options.nix`
- Add `_version` option (internal)

**Files to create/update:**
- `options.nix` - Add versioning

#### 4. **Default.nix Structure**

**Current State:**
- Likely has options and commands inline

**Target State:**
- Import `options.nix`
- Import `commands.nix`
- Use `mkMerge` pattern
- Add enable mapping

**Files to update:**
- `default.nix` - Refactor structure

## Refactoring Steps

### Step 1: Create Core Files
- [ ] Create `options.nix` - Extract all options from `default.nix`
- [ ] Add `moduleVersion = "1.0"` to `options.nix`
- [ ] Add `_version` option to `options.nix`
- [ ] Create `commands.nix` - Move command registration from `default.nix`

### Step 2: Reorganize Files
- [ ] Review `auth.nix` - move to `handlers/` or `validators/`
- [ ] Review `monitoring.nix` - move to `monitors/` or `handlers/`
- [ ] Review `notifications.nix` - move to `notifiers/` or `handlers/`

### Step 3: Update default.nix
- [ ] Remove option definitions
- [ ] Remove command registration
- [ ] Import `options.nix`
- [ ] Import `commands.nix`
- [ ] Add enable mapping pattern
- [ ] Use `mkMerge` for config

### Step 4: Testing
- [ ] Test: `nixos-rebuild dry-run` works
- [ ] Test: All commands work
- [ ] Test: Feature enables/disables correctly

## Priority Order

1. **HIGH**: Add versioning (required for System Updater)
2. **HIGH**: Create `options.nix` (template compliance)
3. **HIGH**: Create `commands.nix` (template compliance)
4. **MEDIUM**: Reorganize files (better structure)
5. **LOW**: Review file locations (optimization)

## Notes

- `scripts/` directory is correct ✅
- `README.md` exists ✅
- Need to check `default.nix` to see current structure

