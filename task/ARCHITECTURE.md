# 🏗️ GENERIC MODULE ARCHITECTURE - NO HARDCODED PATHS

## 🎯 PROBLEM
- Current: hardcoded paths like `systemConfig.core.management.system-manager.submodules.system-logging`
- Submodules cannot load their configs
- Blind searching instead of intelligent path discovery

## 🎯 SOLUTION: GENERIC PATH DISCOVERY (HARDENED)

### **1. Relative Paths instead of toString (ROBUST)**
```nix
# ❌ DANGEROUS: toString can produce store paths
toString ./core/management/system-manager/submodules/system-logging/
# → "/nix/store/abc123-source/core/management/system-manager/submodules/system-logging/"

# ✅ SAFE: Relative paths from Discovery
{
  name = "system-logging";
  path = ./core/management/system-manager/submodules/system-logging;
  relativePath = "core/management/system-manager/submodules/system-logging";  # ← SAFE!
}
```

### **2. Robust Config Access**
```nix
# ❌ DANGEROUS: Can crash if path doesn't exist
cfg = systemConfig.${moduleConfig.configPath};

# ✅ ROBUST: With lib.attrByPath and defaults
cfg = lib.attrByPath
  (lib.splitString "." moduleConfig.configPath)
  { enable = false; }  # Default if not present
  systemConfig;
```

### **3. Intelligent Path Discovery**
```nix
getModuleConfigPath = relativePath:
  lib.concatStringsSep "." (
    lib.filter (s: s != "") (lib.splitString "/" relativePath)
  );

# Example:
# relativePath: "core/management/system-manager/submodules/system-logging"
# → "core.management.system-manager.submodules.system-logging"
```

### **4. Submodule Config-Loading**
```nix
# Every submodule can load its config ROBUSTLY:
{ config, lib, pkgs, systemConfig, moduleConfig, ... }:
let
  cfg = lib.attrByPath
    (lib.splitString "." moduleConfig.configPath)
    { enable = false; }
    systemConfig;  # ← ROBUST!
in {
  imports = if cfg.enable then [ ./config.nix ] else [];
}
```

### **5. Module Manager generates ALL paths automatically**
```nix
# module-manager/config.nix
automaticModuleConfigs = lib.listToAttrs (
  map (module: {
    name = module.name;
    value = let
      # METADATA read from default.nix (as done in Discovery)
      metadata = module.metadata or {};
      scope = getScope module.relativePath;
      role = metadata.role or "internal";  # Explicit role from metadata!
    in {
      # ROBUST path discovery
      configPath = getModuleConfigPath module.relativePath;
      apiPath = configPath;
      scope = scope;        # "core" | "module"
      role = role;          # "internal" | "optional"
      metadata = metadata;  # Full metadata available
      defaultEnable = getDefaultEnable scope role;  # ← From Scope + Role!
    };
  }) discoveredModules
);
```

## 🎯 ARCHITECTURE PRINCIPLES (HARDENED)

### **Filesystem = Config Structure**
```
core/management/system-manager/submodules/system-logging/
↓ ROBUST
systemConfig.core.management.system-manager.submodules.system-logging
```

### **NO Exceptions**
- ✅ Every module gets its path automatically
- ✅ Submodules work exactly like normal modules
- ✅ Modules work exactly like core modules
- ✅ NO hardcoded paths in modules
- ✅ ROBUST defaults (semantically sensible)

### **Clean Default Rules: Scope × Role**
```
Scope (Origin)      Role (Behavior)     Default
─────────────────────────────────────────────────
core                internal           true    (System details)
core                optional           false   (Debug/Experimental)
module              internal           false   (Module is opt-in)
module              optional           false   (Module submodules may define optional role)
```

**Every module defines its `role` explicitly in `default.nix`!**

### **Robust Discovery**
1. **Relative paths** from Discovery (safe)
2. **Filesystem segments** deterministically into dotted path
3. **No heuristic filters** (.nix, .git, etc.)
4. **Clean path** generation

## 🎯 RESULT (HARDENED)

*For detailed implementation steps, see [IMPLEMENTATION.md](IMPLEMENTATION.md).*

- ✅ **NO hardcoded paths** in modules
- ✅ **ROBUST config access** with lib.attrByPath
- ✅ **Relative paths** instead of dangerous toString
- ✅ **Submodules** can load their configs
- ✅ **Intelligent path discovery** instead of blind searching
- ✅ **Filesystem = Config structure** (1:1 mapping)
- ✅ **All module types** work the same way
- ✅ **NO eval errors** for missing paths

## 🎯 EXAMPLES (HARDENED)

*See [EXAMPLES.md](EXAMPLES.md) for complete working examples and metadata templates.*

### **Core Module:**
```
Path: core/base/desktop/
Config: systemConfig.core.base.desktop
Default: { enable = true; }  # core/internal = true
```

### **Submodule:**
```
Path: core/management/system-manager/submodules/system-logging/
Config: systemConfig.core.management.system-manager.submodules.system-logging
Default: { enable = true; }  # Core policy (from scope, not parent)
```

### **Sub-Sub-Sub-Module (INFINITE depth):**
```
Path: core/management/system-manager/submodules/cli-formatter/submodules/advanced/submodules/deep/
Config: systemConfig.core.management.system-manager.submodules.cli-formatter.submodules.advanced.submodules.deep
Default: { enable = true; }  # Core default (automatically inherited)
```

### **Module Submodule:**
```
Path: modules/security/ssh-client-manager/submodules/advanced/
Config: systemConfig.modules.security.ssh-client-manager.submodules.advanced
Default: { enable = false; }  # Module policy (from scope, not parent)
```

### **Module:**
```
Path: modules/security/ssh-client-manager/
Config: systemConfig.modules.security.ssh-client-manager
Default: { enable = false; }  # Module default
```

**Everything automatically generated - ROBUST and NO hardcoded paths!** 🎯

## 🟡 CRITICAL SAFETY FIXES (VERY IMPORTANT!)

### **⚠️ PROBLEM 1: "Explicit" but not enforced**
You say "EVERY module defines its role explicitly" but code does:
```nix
role = metadata.role or "internal";
```

**Why dangerous:**
- Someone forgets `role`
- Submodules become silently `internal`
- `defaultEnable = true` (for core)
- Unexpected behavior

**✅ Solution (very important!)**

Distinguish Root-Modules vs Submodules:

```nix
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
```

**💡 Root-Modules MUST be explicit, Submodules may be implicit.**
**This fits semantically perfectly.**

### **⚠️ PROBLEM 2: "Inherit defaults" but technically don't**
Text says "Submodules inherit defaults from parent" but technically:
```nix
defaultEnable = getDefaultEnable scope role;
```

**Important:** They don't inherit from parent, they inherit from scope.
This is okay - but then say it honestly.

**✅ Clean, honest formulation**
```
Submodules do not inherit behavior,
they inherit policy from their scope.
```
This is more stable and easier to reason about.

## 🎯 **ANSWER TO YOUR QUESTION:**

**NO!** I don't need to define separate types for `subsubmodule`, `subsubsubsubsubsubmodule` etc.!

**The solution:** All submodules (regardless of depth) automatically get the same type as their root parent:

- Under `core/` → All submodules = `type = "core"` → `enable = true`
- Under `modules/` → All submodules = `type = "module"` → `enable = false`

**This scales infinitely!** No hardcoded types needed. 🎯

*Ready to migrate? See [MIGRATION.md](MIGRATION.md) for the complete migration guide.*
