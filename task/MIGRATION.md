# 🔄 MIGRATION GUIDE

*For architecture overview, see [ARCHITECTURE.md](ARCHITECTURE.md). For implementation details, see [IMPLEMENTATION.md](IMPLEMENTATION.md).*

## 🎯 MIGRATING TO SCOPE × ROLE ARCHITECTURE

### **Phase 1: Preparation (No Breaking Changes)**

1. **Add Metadata to Root Modules:**
   ```nix
   # Add to EVERY root module's default.nix
   _module.metadata = {
     role = "internal";  # or "optional"
     name = "my-module";
     description = "What this module does";
     # ... other metadata fields
   };
   ```

2. **Update Module Manager:**
   - Implement `getScope`, `getRole`, `isRootModule` functions
   - Add `automaticModuleConfigs` generation
   - Keep existing hardcoded configs as fallback

3. **Test Discovery:**
   - Ensure all modules are discovered correctly
   - Verify metadata is read from `default.nix` files
   - Check that assertions work for missing roles

### **Phase 2: Gradual Migration (Backward Compatible)**

1. **Migrate Core Modules First:**
   ```nix
   # OLD: Hardcoded path
   cfg = systemConfig.core.management.systemManager;

   # NEW: Dynamic path
   cfg = lib.attrByPath
     (lib.splitString "." moduleConfig.configPath)
     { enable = moduleConfig.defaultEnable; }
     systemConfig;
   ```

2. **Update Imports:**
   ```nix
   # OLD: Static imports
   imports = [ ./system-logging.nix ];

   # NEW: Conditional imports based on config
   imports = if cfg.enable then [ ./system-logging.nix ] else [];
   ```

3. **Add Debug Assertions (Optional):**
   ```nix
   assertions = lib.optionals (config.debug or false) [
     {
       assertion = lib.hasAttrByPath
         (lib.splitString "." moduleConfig.configPath)
         systemConfig;
       message = "Missing config path: ${moduleConfig.configPath}";
     }
   ];
   ```

### **Phase 3: Remove Legacy Code (Breaking Changes)**

1. **Remove Hardcoded Paths:**
   - Delete all `systemConfig.core.*` and `systemConfig.modules.*` references
   - Remove module-specific enable options from main config

2. **Clean Up Imports:**
   - Remove conditional imports that are now handled automatically
   - Update module structure to use `moduleConfig` consistently

3. **Update Documentation:**
   - Remove references to hardcoded paths
   - Update examples to show new patterns

## 🎯 MIGRATION CHECKLIST

### **For Each Module:**

- [ ] Add complete `_module.metadata` to `default.nix`
- [ ] Replace hardcoded `systemConfig.*` with `lib.attrByPath` pattern
- [ ] Add `moduleConfig` parameter to module function
- [ ] Update imports to be conditional on `cfg.enable`
- [ ] Test with `debug = true` to catch missing configs
- [ ] Verify default behavior matches expectations

### **For Module Manager:**

- [ ] Implement `getModuleConfigPath` in `config-helpers.nix`
- [ ] Add `getScope`, `getRole`, `isRootModule` functions
- [ ] Generate `automaticModuleConfigs` from discovered modules
- [ ] Pass `moduleConfig` to all modules via `_module.args`
- [ ] Remove legacy hardcoded configurations

### **For System Configuration:**

- [ ] Update user configs to use new paths if changed
- [ ] Test all module combinations (enable/disable)
- [ ] Verify core modules still enable by default
- [ ] Check that optional modules remain disabled

## 🎯 COMMON MIGRATION ISSUES

### **Issue: "Root module must define explicit role"**
**Symptom:** Build fails with assertion error
**Cause:** Root module missing `role` in `_module.metadata`
**Fix:**
```nix
_module.metadata = {
  role = "internal";  # Add this!
  # ... rest of metadata
};
```

### **Issue: Module not loading**
**Symptom:** Module code doesn't execute despite `enable = true`
**Cause:** Wrong default calculation or missing config path
**Fix:** Check scope/role combination and verify `moduleConfig.defaultEnable`

### **Issue: Config path not found**
**Symptom:** `lib.attrByPath` returns default instead of user config
**Cause:** Mismatch between generated path and actual config structure
**Fix:** Debug `moduleConfig.configPath` and compare with your `systemConfig` structure

### **Issue: Submodules not inheriting correctly**
**Symptom:** Submodules have wrong defaults
**Cause:** Confusion between "inherit from parent" vs "inherit from scope"
**Fix:** Remember - submodules inherit from scope, not parent module

## 🎯 TESTING YOUR MIGRATION

### **Unit Tests:**
```bash
# Test path generation
nix-instantiate --eval -E 'getModuleConfigPath "core/base/desktop"' # → "core.base.desktop"

# Test scope detection
nix-instantiate --eval -E 'getScope "modules/security/ssh"' # → "module"

# Test role validation
nix-instantiate --eval -E 'getRole { relativePath = "core/test"; metadata = { role = "internal"; }; }'
```

### **Integration Tests:**
```bash
# Test with minimal config
nix-build -E 'import ./test-config.nix' --arg config '{ debug = true; }'

# Test module discovery
nix-instantiate --eval -E '(import ./module-manager/config.nix).automaticModuleConfigs'
```

### **Manual Testing:**
1. Enable `debug = true` temporarily
2. Try enabling/disabling various module combinations
3. Verify core modules enable by default
4. Check that optional modules stay disabled
5. Test deep submodule nesting

## 🎯 ROLLBACK PLAN

If migration fails:

1. **Keep legacy code** as fallback in module manager
2. **Use feature flags** to switch between old/new behavior
3. **Gradual rollout** - migrate one module type at a time
4. **Version checkpoints** - commit after each successful module migration

## 🎯 POST-MIGRATION

After successful migration:

- [ ] Remove legacy code and feature flags
- [ ] Update all documentation and examples
- [ ] Create new module template with proper metadata
- [ ] Set up CI/CD to validate metadata in new modules
- [ ] Document the new architecture for future contributors

**Migration complete! Your module system now scales infinitely with no hardcoded paths!** 🎯
