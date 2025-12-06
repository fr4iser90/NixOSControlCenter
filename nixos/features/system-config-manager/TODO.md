# TODO: Refactor system-config-manager to match Template Structure

This document tracks all changes needed to refactor `system-config-manager` to match the template structure defined in `.TEMPLATE/README.md`.

## Current Structure Analysis

### ✅ Already Present
- `default.nix` - ✅ Exists (main entry point)

### ❌ Needs Refactoring

#### 1. **Core Files Missing**

**Current State:**
- No `README.md`
- No `options.nix` (options likely in `default.nix`)
- No `commands.nix` (if commands exist)
- No other directories

**Target State:**
- Create all core files according to template

**Files to create:**
- `README.md` - Feature documentation
- `options.nix` - Configuration options
- `commands.nix` - Command registration (if commands exist)

#### 2. **Versioning**

**Current State:**
- No versioning implemented

**Target State:**
- Add `featureVersion = "1.0"` in `options.nix`
- Add `_version` option (internal)

**Files to create/update:**
- `options.nix` - Add versioning

#### 3. **Default.nix Structure**

**Current State:**
- Need to check structure

**Target State:**
- Import `options.nix`
- Use `mkMerge` pattern
- Add enable mapping: `systemConfig.features.system-config-manager` → `config.features.system-config-manager.enable`
- Add `mkIf cfg.enable` block

**Files to update:**
- `default.nix` - Refactor structure

## Refactoring Steps

### Step 1: Analyze Current Structure
- [ ] Read `default.nix` to understand current implementation
- [ ] Identify what options exist
- [ ] Identify if commands exist
- [ ] Identify what functionality exists

### Step 2: Create Core Files
- [ ] Create `README.md` with feature documentation
- [ ] Create `options.nix` - Extract all options from `default.nix`
- [ ] Add `featureVersion = "1.0"` to `options.nix`
- [ ] Add `_version` option to `options.nix`
- [ ] Create `commands.nix` if commands exist

### Step 3: Update default.nix
- [ ] Remove option definitions (move to `options.nix`)
- [ ] Import `options.nix`
- [ ] Add enable mapping pattern
- [ ] Use `mkMerge` for config
- [ ] Add `mkIf cfg.enable` block

### Step 4: Testing
- [ ] Test: `nixos-rebuild dry-run` works
- [ ] Test: Feature enables/disables correctly

## Priority Order

1. **HIGH**: Analyze current structure
2. **HIGH**: Add versioning (required for System Updater)
3. **HIGH**: Create `options.nix` (template compliance)
4. **HIGH**: Update `default.nix` structure (template compliance)
5. **MEDIUM**: Create `README.md` (documentation)

## Notes

- Feature seems minimal - need to check `default.nix` first
- May not need `commands.nix` if no user commands

