# TODO: Refactor homelab-manager to match Template Structure

This document tracks all changes needed to refactor `homelab-manager` to match the template structure defined in `.TEMPLATE/README.md`.

## Current Structure Analysis

### ✅ Already Present
- `default.nix` - ✅ Exists (main entry point)
- Multiple files in root: `homelab-create.nix`, `homelab-delete.nix`, `homelab-fetch.nix`, `homelab-status.nix`, `homelab-update.nix`

### ❌ Needs Refactoring

#### 1. **File Organization**

**Current State:**
- Files in root: `homelab-create.nix`, `homelab-delete.nix`, etc.
- These look like scripts or handlers

**Target State:**
- Move to appropriate directories

**Files to move:**
- `homelab-create.nix` → `scripts/create.nix` or `handlers/create.nix`
- `homelab-delete.nix` → `scripts/delete.nix` or `handlers/delete.nix`
- `homelab-fetch.nix` → `scripts/fetch.nix` or `handlers/fetch.nix`
- `homelab-status.nix` → `scripts/status.nix` or `handlers/status.nix`
- `homelab-update.nix` → `scripts/update.nix` or `handlers/update.nix`

**Decision needed:**
- Are these scripts (user commands) or handlers (internal logic)?
- If scripts → `scripts/`
- If handlers → `handlers/`

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
- `scripts/` or `handlers/` directory

#### 3. **Versioning**

**Current State:**
- No versioning implemented

**Target State:**
- Add `featureVersion = "1.0"` in `options.nix`
- Add `_version` option (internal)

**Files to create/update:**
- `options.nix` - Add versioning

#### 4. **Default.nix Structure**

**Current State:**
- Need to check structure

**Target State:**
- Import `options.nix`
- Import `commands.nix`
- Use `mkMerge` pattern
- Add enable mapping

**Files to update:**
- `default.nix` - Refactor structure

## Refactoring Steps

### Step 1: Analyze Current Structure
- [ ] Read `default.nix` to understand current implementation
- [ ] Read one of the `homelab-*.nix` files to determine if script or handler
- [ ] Identify what options exist
- [ ] Identify what commands exist

### Step 2: Create Core Files
- [ ] Create `README.md` with feature documentation
- [ ] Create `options.nix` - Extract all options from `default.nix`
- [ ] Add `featureVersion = "1.0"` to `options.nix`
- [ ] Add `_version` option to `options.nix`
- [ ] Create `commands.nix` - Move command registration from `default.nix`
- [ ] Create `scripts/` or `handlers/` directory

### Step 3: Reorganize Files
- [ ] Move `homelab-create.nix` → appropriate directory
- [ ] Move `homelab-delete.nix` → appropriate directory
- [ ] Move `homelab-fetch.nix` → appropriate directory
- [ ] Move `homelab-status.nix` → appropriate directory
- [ ] Move `homelab-update.nix` → appropriate directory

### Step 4: Update default.nix
- [ ] Remove option definitions
- [ ] Remove command registration
- [ ] Import `options.nix`
- [ ] Import `commands.nix`
- [ ] Add enable mapping pattern
- [ ] Use `mkMerge` for config

### Step 5: Testing
- [ ] Test: `nixos-rebuild dry-run` works
- [ ] Test: All commands work
- [ ] Test: Feature enables/disables correctly

## Priority Order

1. **HIGH**: Analyze current structure
2. **HIGH**: Add versioning (required for System Updater)
3. **HIGH**: Create `options.nix` (template compliance)
4. **HIGH**: Create `commands.nix` (template compliance)
5. **MEDIUM**: Reorganize files (better structure)
6. **MEDIUM**: Create `README.md` (documentation)

## Notes

- Files look like they might be scripts (user commands)
- Need to check `default.nix` to see how they're used
- Similar structure to `hackathon-manager`

