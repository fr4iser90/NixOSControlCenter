# TODO: Refactor ssh-client-manager to match Template Structure

This document tracks all changes needed to refactor `ssh-client-manager` to match the template structure defined in `.TEMPLATE/README.md`.

## Current Structure Analysis

### ✅ Already Present
- `README.md` - ❌ Missing (should exist)
- `default.nix` - ✅ Exists (main entry point)
- `options.nix` - ✅ Exists
- `scripts/` - ✅ Exists (directory)
- `lib/` - ❌ Missing (utilities are in root: `ssh-key-utils.nix`, `ssh-server-utils.nix`)

### ❌ Needs Refactoring

#### 1. **File Organization**

**Current State:**
- Files in root: `connection-handler.nix`, `connection-preview.nix`, `init.nix`, `main.nix`, `ssh-key-utils.nix`, `ssh-server-utils.nix`
- Scripts directory exists but may be empty

**Target State:**
- Move handlers to `handlers/` directory
- Move utilities to `lib/` directory
- Organize scripts in `scripts/` directory

**Files to move:**
- `connection-handler.nix` → `handlers/connection-handler.nix`
- `connection-preview.nix` → `handlers/connection-preview.nix` (or `formatters/` if it's formatting)
- `ssh-key-utils.nix` → `lib/ssh-key-utils.nix`
- `ssh-server-utils.nix` → `lib/ssh-server-utils.nix`
- `init.nix` → Check if this is a handler or script
- `main.nix` → Check if this is command registration (should be `commands.nix`)

#### 2. **Command Registration**

**Current State:**
- Commands likely registered in `main.nix`

**Target State:**
- Create `commands.nix` for Command-Center registration
- Move all command registration from `main.nix` to `commands.nix`
- Ensure commands are inside `mkIf cfg.enable` block

**Files to create:**
- `commands.nix` - Command-Center registration

**Files to update:**
- `main.nix` - Move command registration to `commands.nix` or remove if only registration

#### 3. **Versioning**

**Current State:**
- No versioning implemented

**Target State:**
- Add `featureVersion = "1.0"` in `options.nix`
- Add `_version` option (internal)

**Files to update:**
- `options.nix` - Add versioning

#### 4. **Documentation**

**Current State:**
- `README.md` - ❌ Missing

**Target State:**
- Create `README.md` with feature documentation

**Files to create:**
- `README.md` - Feature documentation

## Refactoring Steps

### Step 1: Create Missing Core Files
- [ ] Create `README.md` with feature documentation
- [ ] Create `commands.nix` for command registration
- [ ] Create `lib/default.nix` to export utilities

### Step 2: Reorganize Files
- [ ] Move `connection-handler.nix` → `handlers/connection-handler.nix`
- [ ] Move `connection-preview.nix` → `handlers/connection-preview.nix` (or appropriate directory)
- [ ] Move `ssh-key-utils.nix` → `lib/ssh-key-utils.nix`
- [ ] Move `ssh-server-utils.nix` → `lib/ssh-server-utils.nix`
- [ ] Review `init.nix` and `main.nix` - determine correct location

### Step 3: Update Imports
- [ ] Update `default.nix` imports to reflect new structure
- [ ] Update all file references in moved files

### Step 4: Add Versioning
- [ ] Add `featureVersion = "1.0"` to `options.nix`
- [ ] Add `_version` option to `options.nix`

### Step 5: Command Registration
- [ ] Move command registration from `main.nix` to `commands.nix`
- [ ] Ensure commands are in `mkIf cfg.enable` block
- [ ] Test all commands work

### Step 6: Testing
- [ ] Test: `nixos-rebuild dry-run` works
- [ ] Test: All commands work
- [ ] Test: Feature enables/disables correctly

## Priority Order

1. **HIGH**: Add versioning (required for System Updater)
2. **HIGH**: Create `commands.nix` (template compliance)
3. **MEDIUM**: Reorganize files (better structure)
4. **MEDIUM**: Create `README.md` (documentation)
5. **LOW**: Move utilities to `lib/` (cleanup)

## Notes

- `scripts/` directory exists but may need content review
- `main.nix` might be command registration - check and move to `commands.nix`
- `init.nix` might be initialization logic - could be handler or script

