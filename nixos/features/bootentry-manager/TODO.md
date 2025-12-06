# TODO: Refactor bootentry-manager to match Template Structure

This document tracks all changes needed to refactor `bootentry-manager` to match the template structure defined in `.TEMPLATE/README.md`.

## Current Structure Analysis

### ✅ Already Present
- `default.nix` - ✅ Exists (main entry point)
- `lib/` - ✅ Exists (utilities)
- `lib/types.nix` - ✅ Exists (custom types)
- `lib/common.nix` - ✅ Exists (common utilities)
- `providers/` - ✅ Exists (semantic, acceptable - provider pattern is central)

### ❌ Needs Refactoring

#### 1. **Core Files Missing**

**Current State:**
- No `README.md`
- No `options.nix` (options defined inline in `default.nix`)
- No `commands.nix` (if commands exist)
- No `types.nix` at root (types in `lib/types.nix`)

**Target State:**
- Create all core files according to template

**Files to create:**
- `README.md` - Feature documentation
- `options.nix` - Move all options from `default.nix`
- `commands.nix` - Command registration (if commands exist)
- `types.nix` - Move or reference `lib/types.nix` (if needed at root)

#### 2. **Options in default.nix**

**Current State:**
- Options defined inline in `default.nix`:
  ```nix
  options.features.bootentry-manager = {
    enable = mkEnableOption "boot entry manager";
    description = mkOption { ... };
  };
  ```

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
- Add `featureVersion = "1.0"` in `options.nix`
- Add `_version` option (internal)

**Files to create/update:**
- `options.nix` - Add versioning

#### 4. **Default.nix Structure**

**Current State:**
- Options defined inline
- No enable mapping pattern
- Uses `mkIf cfg.enable` correctly

**Target State:**
- Use `mkMerge` pattern
- Add enable mapping: `systemConfig.features.bootentry-manager` → `config.features.bootentry-manager.enable`
- Import `options.nix`

**Files to update:**
- `default.nix` - Refactor structure

## Refactoring Steps

### Step 1: Create Core Files
- [ ] Create `README.md` with feature documentation
- [ ] Create `options.nix` - Move all options from `default.nix`
- [ ] Add `featureVersion = "1.0"` to `options.nix`
- [ ] Add `_version` option to `options.nix`

### Step 2: Update default.nix
- [ ] Remove option definitions
- [ ] Import `options.nix`
- [ ] Add enable mapping pattern
- [ ] Use `mkMerge` for config
- [ ] Keep `mkIf cfg.enable` block

### Step 3: Command Registration (if needed)
- [ ] Check if feature has commands
- [ ] If yes, create `commands.nix`
- [ ] Register commands in Command-Center

### Step 4: Testing
- [ ] Test: `nixos-rebuild dry-run` works
- [ ] Test: Feature enables/disables correctly
- [ ] Test: All providers work

## Priority Order

1. **HIGH**: Add versioning (required for System Updater)
2. **HIGH**: Create `options.nix` (template compliance)
3. **HIGH**: Update `default.nix` structure (template compliance)
4. **MEDIUM**: Create `README.md` (documentation)
5. **LOW**: Review if `commands.nix` needed

## Notes

- `providers/` is semantic but acceptable (provider pattern is central to this feature)
- `lib/` structure is good (utilities organized)
- Feature seems to be system-level (no user commands), so `commands.nix` might not be needed

