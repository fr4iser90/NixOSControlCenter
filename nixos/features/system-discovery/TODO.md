# TODO: Refactor system-discovery to match Template Structure

This document tracks all changes needed to refactor `system-discovery` to match the template structure defined in `.TEMPLATE/README.md`.

## File Structure Changes

### ✅ Already Correct
- `README.md` - Exists
- `ARCHITECTURE.md` - Detailed documentation
- `scanners/` - Semantic naming is acceptable (scanning is core concept)

### ❌ Needs Refactoring

#### 1. **Split `default.nix` into separate modules**

**Current State:**
- All options defined inline in `default.nix`
- All commands registered inline in `default.nix`
- Systemd services/timers defined inline in `default.nix`
- All scripts created inline in `default.nix`

**Target State:**
- Move all options to `options.nix` (currently empty)
- Move command registration to `commands.nix` (new file)
- Move systemd definitions to `systemd.nix` (new file)
- `default.nix` should only import sub-modules and define enable mapping

**Files to create:**
- `commands.nix` - Command-Center registration
- `systemd.nix` - Systemd services/timers

**Files to update:**
- `options.nix` - Move all options from `default.nix`
- `default.nix` - Simplify to only imports and enable mapping

#### 2. **Move scripts to `scripts/` directory**

**Current State:**
- Scripts created inline in `default.nix`:
  - `discoverScript` → should be `scripts/discover.nix`
  - `restoreScript` → should be `scripts/restore.nix`
  - `fetchScript` → should be `scripts/fetch.nix`
  - `restoreFromGitHubScript` → should be `scripts/restore-from-github.nix`

**Target State:**
- Create `scripts/` directory
- Move each script to its own file
- Import scripts in `commands.nix`

**Files to create:**
- `scripts/discover.nix`
- `scripts/restore.nix`
- `scripts/fetch.nix`
- `scripts/restore-from-github.nix`

#### 3. **Move handlers to `handlers/` directory**

**Current State:**
- Handler files in root directory:
  - `encryption.nix` → should be `handlers/encryption.nix`
  - `github-upload.nix` → should be `handlers/github-upload.nix`
  - `github-download.nix` → should be `handlers/github-download.nix`
  - `restore.nix` → should be `handlers/restore.nix`
  - `snapshot-generator.nix` → should be `handlers/snapshot-generator.nix`

**Target State:**
- Create `handlers/` directory
- Move all handler files to `handlers/`
- Update imports in `default.nix` and `commands.nix`

**Files to create:**
- `handlers/` directory
- Move existing files to `handlers/`

**Files to update:**
- `default.nix` - Update import paths
- `commands.nix` - Update import paths (when created)

#### 4. **Create `lib/` directory (if needed)**

**Current State:**
- No shared utility functions extracted

**Target State:**
- If utility functions are needed, create `lib/` directory
- Extract reusable functions to `lib/utils.nix`

**Files to create (if needed):**
- `lib/default.nix`
- `lib/utils.nix`

#### 5. **Create `types.nix` (if needed)**

**Current State:**
- No custom types defined

**Target State:**
- If custom types are needed, create `types.nix`
- Extract type definitions from options

**Files to create (if needed):**
- `types.nix`

## Implementation Checklist

### Phase 1: File Structure
- [ ] Create `commands.nix`
- [ ] Create `systemd.nix`
- [ ] Create `scripts/` directory
- [ ] Create `handlers/` directory
- [ ] Create `lib/` directory (if needed)
- [ ] Create `types.nix` (if needed)

### Phase 2: Move Options
- [ ] Move all options from `default.nix` to `options.nix`
- [ ] Verify all options have proper descriptions
- [ ] Test that options still work

### Phase 3: Move Scripts
- [ ] Extract `discoverScript` to `scripts/discover.nix`
- [ ] Extract `restoreScript` to `scripts/restore.nix`
- [ ] Extract `fetchScript` to `scripts/fetch.nix`
- [ ] Extract `restoreFromGitHubScript` to `scripts/restore-from-github.nix`
- [ ] Update `commands.nix` to import and register scripts

### Phase 4: Move Handlers
- [ ] Move `encryption.nix` to `handlers/encryption.nix`
- [ ] Move `github-upload.nix` to `handlers/github-upload.nix`
- [ ] Move `github-download.nix` to `handlers/github-download.nix`
- [ ] Move `restore.nix` to `handlers/restore.nix`
- [ ] Move `snapshot-generator.nix` to `handlers/snapshot-generator.nix`
- [ ] Update all import paths

### Phase 5: Refactor default.nix
- [ ] Simplify `default.nix` to only imports
- [ ] Remove inline options
- [ ] Remove inline scripts
- [ ] Remove inline systemd definitions
- [ ] Keep only enable mapping and imports

### Phase 6: Testing
- [ ] Test feature enable/disable
- [ ] Test all commands work
- [ ] Test systemd timer (if configured)
- [ ] Test snapshot generation
- [ ] Test encryption
- [ ] Test GitHub upload/download
- [ ] Test restore functionality

## Notes

- Keep `scanners/` as semantic name (scanning is core concept)
- All handlers should be in `handlers/` for consistency
- All scripts should be in `scripts/` for consistency
- Options must be in `options.nix` (separation of concerns)
- Commands must be registered in `commands.nix` inside `mkIf cfg.enable`
- Systemd definitions must be in `systemd.nix`

## Migration Order

1. **First**: Create new directory structure
2. **Second**: Move handlers (least breaking)
3. **Third**: Move scripts (medium breaking)
4. **Fourth**: Move options (more breaking)
5. **Fifth**: Create commands.nix and systemd.nix
6. **Last**: Refactor default.nix (most breaking)

## Breaking Changes

- Import paths will change for handlers
- Script paths will change
- Options location will change
- Need to update any external references

