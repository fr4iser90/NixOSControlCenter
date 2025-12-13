# Task 1: Module Metadata System & Foundations

## 🎯 Goal
Implement the module metadata system to replace hardcoded categories with self-describing modules.

## 📋 Description
Modules should define their own metadata (defaultCategory, allowedCategories, supportsUserConfig) instead of having categories hardcoded in the module manager. This enables better validation, flexibility, and UX for module authors.

## ✅ Acceptance Criteria
- [ ] Module metadata schema defined and validated
- [ ] All existing modules have metadata defined
- [ ] Metadata loader integrated into module discovery
- [ ] Validation prevents invalid category assignments
- [ ] Backward compatibility maintained

## 🔧 Implementation Details

### 1.1 Define Metadata Schema
```nix
# In module-manager/lib/default.nix
moduleMetadataSchema = {
  name = lib.types.str;                    # required
  description = lib.types.str;             # required
  defaultCategory = lib.types.enum ["system" "shared" "user"];
  allowedCategories = lib.types.listOf (lib.types.enum ["system" "shared" "user"]);
  supportsUserConfig = lib.types.bool;     # default: false
  version = lib.types.str;                  # for migrations
};
```

### 1.2 Update Module Discovery
- Load metadata from each module's `default.nix` or dedicated `metadata.nix`
- Validate against schema
- Generate default categories for modules without metadata (backward compatibility)
- Cache metadata for performance

### 1.3 Add Validation
- Prevent modules from being assigned to disallowed categories
- Warn about missing metadata
- Validate category transitions during migration

## 🧪 Testing
- [ ] Unit tests for metadata loading
- [ ] Validation tests for invalid metadata
- [ ] Backward compatibility tests with old modules
- [ ] Schema validation edge cases

## 📅 Dependencies
- None (foundational task)

## ⏱️ Estimated Duration
1-2 days

## 📁 Files to Create/Modify
- `nixos/core/management/module-manager/lib/default.nix` - Add metadata schema & loader
- `nixos/core/management/module-manager/lib/metadata-loader.nix` - New file
- `docs/02_architecture/example_module/metadata.nix` - Example metadata file
- `docs/02_architecture/example_module/MODULE_TEMPLATE.md` - Update template

## 🎯 Next Steps
After completion, enables Task 2 (Config Path Resolver) to use metadata instead of hardcoded categories.
