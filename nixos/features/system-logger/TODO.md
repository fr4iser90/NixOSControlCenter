# TODO: Refactor system-logger to match Template Structure

This document tracks all changes needed to refactor `system-logger` to match the template structure defined in `.TEMPLATE/README.md`.

## Current Structure Analysis

### ✅ Already Present
- `default.nix` - ✅ Exists (main entry point)
- `collectors/` - ✅ Exists (generic naming, correct!)
- Multiple collectors: `bootentries.nix`, `bootloader.nix`, `desktop.nix`, etc.

### ❌ Needs Refactoring

#### 1. **Core Files Missing**

**Current State:**
- No `README.md`
- No `options.nix` (options defined inline in `default.nix`)
- No `commands.nix` (if commands exist)
- No `types.nix` (if custom types needed)

**Target State:**
- Create all core files according to template

**Files to create:**
- `README.md` - Feature documentation
- `options.nix` - Move all options from `default.nix`
- `commands.nix` - Command registration (if commands exist)

#### 2. **Options in default.nix**

**Current State:**
- Options defined inline in `default.nix`:
  - `options.features.system-logger.enable`
  - `options.features.system-logger.defaultDetailLevel`
  - `options.features.system-logger.collectors.*`

**Target State:**
- Move all options to `options.nix`
- `default.nix` should only import and map enable

**Files to create:**
- `options.nix` - All option definitions

**Files to update:**
- `default.nix` - Remove option definitions, import `options.nix`

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
- Options defined inline
- Uses `mkMerge` correctly ✅
- Uses `mkIf cfg.enable` correctly ✅
- No enable mapping pattern

**Target State:**
- Add enable mapping: `systemConfig.features.system-logger` → `config.features.system-logger.enable`
- Import `options.nix`

**Files to update:**
- `default.nix` - Add enable mapping, import `options.nix`

## Refactoring Steps

### Step 1: Create Core Files
- [ ] Create `README.md` with feature documentation
- [ ] Create `options.nix` - Move all options from `default.nix`
- [ ] Add `moduleVersion = "1.0"` to `options.nix`
- [ ] Add `_version` option to `options.nix`

### Step 2: Update default.nix
- [ ] Remove option definitions
- [ ] Import `options.nix`
- [ ] Add enable mapping pattern
- [ ] Keep `mkMerge` and `mkIf cfg.enable` (already correct)

### Step 3: Command Registration (if needed)
- [ ] Check if feature has commands
- [ ] If yes, create `commands.nix`
- [ ] Register commands in Command-Center

### Step 4: Testing
- [ ] Test: `nixos-rebuild dry-run` works
- [ ] Test: Feature enables/disables correctly
- [ ] Test: All collectors work

## Priority Order

1. **HIGH**: Add versioning (required for System Updater)
2. **HIGH**: Create `options.nix` (template compliance)
3. **HIGH**: Update `default.nix` structure (template compliance)
4. **MEDIUM**: Create `README.md` (documentation)
5. **LOW**: Review if `commands.nix` needed

## Notes

- `collectors/` is perfect generic naming ✅
- Structure is already quite good (uses `mkMerge`, `mkIf`)
- Just needs options extraction and versioning

