# TODO: Refactor system-checks to match Template Structure

This document tracks all changes needed to refactor `system-checks` to match the template structure defined in `.TEMPLATE/README.md`.

## Current Structure Analysis

### ✅ Already Present
- `default.nix` - ✅ Exists (main entry point)
- `prebuild/` - ✅ Exists (semantic, but acceptable for build phases)
- `postbuild/` - ✅ Exists (semantic, but acceptable for build phases)
- `prebuild/checks/` - ✅ Exists (check logic)
- `prebuild/lib/` - ✅ Exists (utilities)

### ❌ Needs Refactoring

#### 1. **Core Files Missing**

**Current State:**
- No `README.md`
- No `options.nix`
- No `commands.nix`
- No `types.nix` (if custom types needed)

**Target State:**
- Create all core files according to template

**Files to create:**
- `README.md` - Feature documentation
- `options.nix` - Configuration options
- `commands.nix` - Command registration (if commands exist)
- `types.nix` - Custom types (if needed, check `prebuild/lib/types.nix`)

#### 2. **Versioning**

**Current State:**
- No versioning implemented

**Target State:**
- Add `featureVersion = "1.0"` in `options.nix`
- Add `_version` option (internal)

**Files to create/update:**
- `options.nix` - Add versioning and all options

#### 3. **Default.nix Structure**

**Current State:**
- Very minimal `default.nix`
- No enable mapping
- No `mkIf cfg.enable` pattern

**Target State:**
- Add enable mapping: `systemConfig.features.system-checks` → `config.features.system-checks.enable`
- Use `mkMerge` pattern
- Add `mkIf cfg.enable` block

**Files to update:**
- `default.nix` - Add proper structure

#### 4. **Directory Organization**

**Current State:**
- `prebuild/checks/` - Contains check logic
- `prebuild/lib/` - Contains utilities

**Target State:**
- Consider if `prebuild/checks/` should be `validators/` or `collectors/`
- Consider if utilities should be in root `lib/` or stay in `prebuild/lib/`

**Decision needed:**
- Are checks validators or collectors?
- Should `prebuild/lib/` move to root `lib/`?

## Refactoring Steps

### Step 1: Create Core Files
- [ ] Create `README.md` with feature documentation
- [ ] Create `options.nix` with all configuration options
- [ ] Add `featureVersion = "1.0"` to `options.nix`
- [ ] Add `_version` option to `options.nix`

### Step 2: Update default.nix
- [ ] Add enable mapping pattern
- [ ] Use `mkMerge` for config
- [ ] Add `mkIf cfg.enable` block
- [ ] Import `options.nix`

### Step 3: Review Directory Structure
- [ ] Decide: `prebuild/checks/` → `validators/` or keep as is?
- [ ] Decide: `prebuild/lib/` → root `lib/` or keep as is?
- [ ] Document decision in README

### Step 4: Command Registration (if needed)
- [ ] Check if feature has commands
- [ ] If yes, create `commands.nix`
- [ ] Register commands in Command-Center

### Step 5: Testing
- [ ] Test: `nixos-rebuild dry-run` works
- [ ] Test: Feature enables/disables correctly
- [ ] Test: All checks work

## Priority Order

1. **HIGH**: Add versioning (required for System Updater)
2. **HIGH**: Create `options.nix` (template compliance)
3. **HIGH**: Update `default.nix` structure (template compliance)
4. **MEDIUM**: Create `README.md` (documentation)
5. **LOW**: Review directory structure (optimization)

## Notes

- `prebuild/` and `postbuild/` are semantic but acceptable (build phases are core concept)
- `prebuild/checks/` might be better as `validators/` but current structure works
- Feature seems to be system-level (no user commands), so `commands.nix` might not be needed

