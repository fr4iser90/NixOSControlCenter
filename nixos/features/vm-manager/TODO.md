# TODO: Refactor vm-manager to match Template Structure

This document tracks all changes needed to refactor `vm-manager` to match the template structure defined in `.TEMPLATE/README.md`.

## Current Structure Analysis

### ✅ Already Present
- `default.nix` - ✅ Exists (main entry point)
- `lib/` - ✅ Exists (utilities)
- `machines/drivers/` - ✅ Exists (semantic, acceptable - drivers are central)
- `containers/` - ✅ Exists (semantic, acceptable - containers are central)
- `iso-manager/` - ✅ Exists (semantic, acceptable - ISO management is specific)
- `core/` - ✅ Exists
- `base/` - ✅ Exists
- `testing/` - ✅ Exists

### ❌ Needs Refactoring

#### 1. **Core Files Missing**

**Current State:**
- No `README.md`
- No `options.nix` (options likely in `default.nix`)
- No `commands.nix` (if commands exist)
- No `types.nix` (types likely in `lib/types.nix`)

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
- Add enable mapping: `systemConfig.features.vm-manager` → `config.features.vm-manager.enable`
- Add `mkIf cfg.enable` block

**Files to update:**
- `default.nix` - Refactor structure

#### 4. **Directory Organization**

**Current State:**
- Complex structure with semantic directories
- `machines/drivers/` - Semantic but acceptable
- `containers/` - Semantic but acceptable
- `iso-manager/` - Semantic but acceptable

**Target State:**
- Keep semantic directories (they're central to feature)
- Ensure generic directories are used where appropriate

**Decision:**
- Current structure is acceptable (semantic names are central to feature)
- Just need to add core files and versioning

## Refactoring Steps

### Step 1: Analyze Current Structure
- [ ] Read `default.nix` to understand current implementation
- [ ] Identify what options exist
- [ ] Identify if commands exist
- [ ] Review directory structure

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
- [ ] Test: All VM functionality works

## Priority Order

1. **HIGH**: Analyze current structure
2. **HIGH**: Add versioning (required for System Updater)
3. **HIGH**: Create `options.nix` (template compliance)
4. **HIGH**: Update `default.nix` structure (template compliance)
5. **MEDIUM**: Create `README.md` (documentation)
6. **LOW**: Review directory structure (already acceptable)

## Notes

- Complex feature with many sub-components
- Semantic directories are acceptable (drivers, containers, iso-manager are central)
- `lib/` structure is good
- Just needs core files and versioning

