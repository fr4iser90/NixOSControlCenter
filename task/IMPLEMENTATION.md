# 🔧 IMPLEMENTATION GUIDE

*For architecture overview, see [ARCHITECTURE.md](ARCHITECTURE.md). For working examples, see [EXAMPLES.md](EXAMPLES.md).*

## 🎯 IMPLEMENTATION (HARDENED)

### **Step 1: Robust Path Function**
```nix
# config-helpers.nix
getModuleConfigPath = relativePath:
  lib.concatStringsSep "." (
    lib.filter (s: s != "") (lib.splitString "/" relativePath)
  );
```

### **Step 2: Modules get ROBUST path automatically**
```nix
# Every module:
{ config, lib, pkgs, systemConfig, moduleConfig, ... }:
let
  cfg = lib.attrByPath
    (lib.splitString "." moduleConfig.configPath)
    { enable = moduleConfig.defaultEnable; }  # ← CENTRALLY controlled!
    systemConfig;
in {
  imports = if cfg.enable then [ ./config.nix ] else [];

  # Optional: Debug assertions (only when debug = true)
  assertions = lib.optionals (config.debug or false) [
    {
      assertion = lib.hasAttrByPath
        (lib.splitString "." moduleConfig.configPath)
        systemConfig;
      message = "Missing config path: ${moduleConfig.configPath}";
    }
  ];
}
```

### **Step 3: Module Manager generates everything ROBUSTLY**
```nix
# module-manager/config.nix
let
  # DYNAMIC default control (for INFINITE depth!)
  # Type derived from path structure:
  # - "core/..." → type = "core" (enable = true)
  # - "modules/..." → type = "module" (enable = false)
  # - All submodules inherit policy from their scope (NOT from parent)!

  # CLEAN separation: Scope (origin) + Role (behavior)
  # Explicit metadata instead of name heuristics!

  getScope = relativePath:
    let segments = lib.splitString "/" relativePath;
    in if lib.elemAt segments 0 == "core" then "core"
       else if lib.elemAt segments 0 == "modules" then "module"
       else "unknown";

  # CRITICAL: Distinguish Root-Modules vs Submodules!
  # Root-Modules MUST define role explicitly (Assertion!)
  # Submodules may be implicit "internal"

  isRootModule = relativePath:
    let segments = lib.splitString "/" relativePath;
        depth = lib.length segments;
    in depth == 2;  # core/desktop, modules/security → Root-Modules

  getRole = module:
    let
      metadata = module.metadata or {};
      isRoot = isRootModule module.relativePath;
    in
      # Root-Modules MUST have explicit role!
      if isRoot then
        assert lib.assertMsg (metadata ? role)
          "Root module '${module.name}' must define explicit 'role' in _module.metadata!";
        metadata.role
      else
        # Submodule: may be implicit "internal"
        metadata.role or "internal";

  getDefaultEnable = scope: role:
    if scope == "core" && role == "internal" then true
    else if scope == "core" && role == "optional" then false
    else if scope == "module" then false  # Modules are always opt-in
    else false;  # For safety

  # Type for automatic generation
  getModuleType = relativePath: getScope relativePath;
in {
  _module.args = {
    moduleConfig = automaticModuleConfigs.${moduleName};
  };
}
```

## 🔧 MINIMAL IMPROVEMENTS (BUILT-IN)

### **✅ Removed:**
- `enablePath` (redundant, usable later for UI)

### **✅ Added:**
- **Type System**: `"core" | "module" | "submodule"`
- **Central Defaults**: `moduleDefaults` instead of module hardcodes
- **Debug Assertions**: Optional for development
- **DYNAMIC Type Discovery**: For INFINITE nesting depth!

### **✅ Improved:**
- **Explicit Metadata**: No name heuristics, every module defines its role
- **Scope × Role Matrix**: Clean separation of origin and behavior
- **No implicit logic**: Everything explicit and maintainable
- **Central Default Control**: Scope + Role → deterministic defaults
- **Debugging**: Assertions for refactoring safety

## 🔧 NEXT STEPS

1. **Extend Discovery** to read metadata from default.nix
2. **config-helpers** with robust getModuleConfigPath + Scope/Role logic
3. **Module Manager** with automaticModuleConfigs + metadata integration
4. **All modules** equipped with complete _module.metadata
5. **Migration** to new Scope × Role architecture

**Architecture is now fully hardened with explicit metadata!** 🎯

*For complete API reference, see [REFERENCE.md](REFERENCE.md).*
