# TODO: Refactor ai-workspace to match Template Structure

This document tracks all changes needed to refactor `ai-workspace` to match the template structure defined in `.TEMPLATE/README.md`.

## Current Structure Analysis

### ✅ Already Present
- `default.nix` - ✅ Exists (main entry point)
- `containers/` - ✅ Exists (semantic, acceptable - containers are central)
- `llm/` - ✅ Exists (semantic, acceptable - LLM is core concept)
- `schemas/` - ✅ Exists (semantic, acceptable - schemas are specific)
- `services/` - ✅ Exists (semantic, but consider if should be `handlers/`)

### ❌ Needs Refactoring

#### 1. **Core Files Missing**

**Current State:**
- No `README.md`
- No `options.nix` (options likely in `default.nix`)
- No `commands.nix` (if commands exist)
- No `types.nix` (if custom types needed)

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
- Add `moduleVersion = "1.0"` in `options.nix`
- Add `_version` option (internal)

**Files to create/update:**
- `options.nix` - Add versioning

#### 3. **Directory Organization**

**Current State:**
- `services/` directory exists
- Consider if should be `handlers/` (generic) instead

**Target State:**
- Review if `services/` should be renamed to `handlers/`
- Keep semantic directories that are central (containers, llm, schemas)

**Decision needed:**
- `services/` → `handlers/`? (if it's generic service management logic)
- Keep `services/`? (if service management is core to feature)

#### 4. **Default.nix Structure**

**Current State:**
- Need to check structure

**Target State:**
- Import `options.nix`
- Use `mkMerge` pattern
- Add enable mapping: `systemConfig.features.ai-workspace` → `config.features.ai-workspace.enable`
- Add `mkIf cfg.enable` block

**Files to update:**
- `default.nix` - Refactor structure

## Refactoring Steps

### Step 1: Analyze Current Structure
- [ ] Read `default.nix` to understand current implementation
- [ ] Review `services/` directory - determine if should be `handlers/`
- [ ] Identify what options exist
- [ ] Identify if commands exist

### Step 2: Create Core Files
- [ ] Create `README.md` with feature documentation
- [ ] Create `options.nix` - Extract all options from `default.nix`
- [ ] Add `moduleVersion = "1.0"` to `options.nix`
- [ ] Add `_version` option to `options.nix`
- [ ] Create `commands.nix` if commands exist

### Step 3: Review Directory Structure
- [ ] Review `services/` - decide if rename to `handlers/`
- [ ] Keep semantic directories (containers, llm, schemas)

### Step 4: Update default.nix
- [ ] Remove option definitions (move to `options.nix`)
- [ ] Import `options.nix`
- [ ] Add enable mapping pattern
- [ ] Use `mkMerge` for config
- [ ] Add `mkIf cfg.enable` block

### Step 5: Testing
- [ ] Test: `nixos-rebuild dry-run` works
- [ ] Test: Feature enables/disables correctly
- [ ] Test: All AI workspace functionality works

## Priority Order

1. **HIGH**: Analyze current structure
2. **HIGH**: Add versioning (required for System Updater)
3. **HIGH**: Create `options.nix` (template compliance)
4. **HIGH**: Update `default.nix` structure (template compliance)
5. **MEDIUM**: Review `services/` directory
6. **MEDIUM**: Create `README.md` (documentation)

## Notes

- Complex feature with many sub-components
- Semantic directories are acceptable (containers, llm, schemas are central)
- `services/` might need review - could be `handlers/` if generic
- Just needs core files and versioning

