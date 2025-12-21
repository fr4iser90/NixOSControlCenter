# 📖 API REFERENCE

*For practical examples, see [EXAMPLES.md](EXAMPLES.md). For implementation guide, see [IMPLEMENTATION.md](IMPLEMENTATION.md).*

## 🎯 CORE FUNCTIONS

### **getModuleConfigPath**
Converts filesystem path to config path.

```nix
getModuleConfigPath :: string -> string

# Example:
getModuleConfigPath "core/management/system-manager/submodules/system-logging"
# → "core.management.system-manager.submodules.system-logging"
```

### **getScope**
Determines module scope from relative path.

```nix
getScope :: string -> string  # "core" | "module" | "unknown"

# Examples:
getScope "core/base/desktop"          # → "core"
getScope "modules/security/ssh"       # → "module"
getScope "unknown/path"               # → "unknown"
```

### **isRootModule**
Checks if a module is a root module (depth = 2).

```nix
isRootModule :: string -> bool

# Examples:
isRootModule "core/base/desktop"                    # → false (depth 3)
isRootModule "core/base"                           # → true  (depth 2)
isRootModule "modules/security"                    # → true  (depth 2)
isRootModule "modules/security/ssh/advanced"       # → false (depth 3)
```

### **getRole**
Extracts role from module metadata with validation.

```nix
getRole :: Module -> string  # "internal" | "optional"

# For root modules: REQUIRES explicit role (assertion fails if missing)
# For submodules: defaults to "internal" if not specified

# Examples:
getRole { relativePath = "core/base"; metadata = { role = "internal"; }; }
# → "internal"

getRole { relativePath = "core/base/desktop"; metadata = {}; }
# → "internal" (submodule default)

getRole { relativePath = "core/base"; metadata = {}; }
# ❌ ASSERTION FAILED: Root module 'base' must define explicit 'role'!
```

### **getDefaultEnable**
Calculates default enable state from scope and role.

```nix
getDefaultEnable :: string -> string -> bool

# Matrix:
# scope="core", role="internal" → true
# scope="core", role="optional" → false
# scope="module", role=any      → false  (modules are opt-in)
# else                          → false  (safety default)
```

## 🎯 MODULE CONFIG STRUCTURE

### **moduleConfig Object**
Passed to every module via `_module.args`.

```nix
{
  # Path generation
  configPath = "core.management.system-manager.submodules.system-logging";
  apiPath = "core.management.system-manager.submodules.system-logging";  # Same as configPath

  # Classification
  scope = "core";        # "core" | "module"
  role = "internal";     # "internal" | "optional"

  # Metadata (full copy)
  metadata = {
    name = "system-logging";
    description = "Centralized system logging";
    role = "internal";
    category = "system";
    # ... all metadata fields
  };

  # Default behavior
  defaultEnable = true;  # Calculated from scope × role
}
```

## 🎯 METADATA SCHEMA

### **Required Fields (All Modules)**
```nix
_module.metadata = {
  # ESSENTIAL for default control
  role = "internal";        # "internal" | "optional"
};
```

### **Recommended Fields**
```nix
_module.metadata = {
  # Identification
  name = "my-module";                    # string
  description = "What this module does"; # string

  # Versioning
  version = "1.0.0";                     # string (semver)

  # Categorization
  category = "system";                   # enum: system | management | infrastructure | security | specialized
  subcategory = "logging";               # string (free-form)

  # Dependencies
  dependencies = [                       # array of strings
    "system-checks"
    "command-center"
  ];

  # Search/Filter
  tags = [                               # array of strings
    "monitoring"
    "logging"
    "system"
  ];

  # Support
  stability = "stable";                  # enum: stable | beta | experimental | deprecated
  maintainer = "team-core";               # string
};
```

## 🎯 CONFIG ACCESS PATTERNS

### **Safe Config Access**
```nix
{ config, lib, pkgs, systemConfig, moduleConfig, ... }:
let
  # ✅ SAFE: Always works, has fallback
  cfg = lib.attrByPath
    (lib.splitString "." moduleConfig.configPath)
    { enable = moduleConfig.defaultEnable; }
    systemConfig;
in {
  # Use cfg.enable, cfg.otherOption, etc.
}
```

### **Debug Assertions (Optional)**
```nix
{ config, lib, pkgs, systemConfig, moduleConfig, ... }:
{
  # Only active when debug = true
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

## 🎯 SCOPE × ROLE MATRIX

### **Complete Default Rules**
```
┌─────────────┬────────────┬─────────┐
│ Scope       │ Role       │ Default │
├─────────────┼────────────┼─────────┤
│ core        │ internal   │ true    │  System components
│ core        │ optional   │ false   │  Debug/Experimental
│ module      │ internal   │ false   │  Module is opt-in
│ module      │ optional   │ false   │  Module submodules
│ unknown     │ any        │ false   │  Safety default
└─────────────┴────────────┴─────────┘
```

### **Semantic Meaning**
- **core/internal**: Essential system functionality (always enabled)
- **core/optional**: Advanced/experimental features (user opt-in)
- **module/**: Third-party modules (always opt-in, role irrelevant)

## 🎯 FILESYSTEM LAYOUT

### **Directory Structure**
```
nixos/
├── core/           # scope = "core"
│   ├── base/       # root modules
│   ├── management/ # root modules
│   └── ...
└── modules/        # scope = "module"
    ├── security/   # root modules
    ├── network/    # root modules
    └── ...
```

### **Path Examples**
```
Filesystem Path                          Config Path
─────────────────────────────────────────────────────────────────
core/base/desktop/                       core.base.desktop
core/management/system-manager/          core.management.system-manager
modules/security/ssh-client-manager/     modules.security.ssh-client-manager
core/management/system-manager/submodules/system-logging/
                                        core.management.system-manager.submodules.system-logging
```

## 🎯 ERROR MESSAGES

### **Common Assertions**
- `"Root module 'name' must define explicit 'role' in _module.metadata!"`
- `"Missing config path: path"`

### **Debugging Tips**
1. Enable `debug = true` to see all assertion failures
2. Check `moduleConfig.configPath` matches your `systemConfig` structure
3. Verify scope/role calculation: `scope = "core"` for `core/*`, `"module"` for `modules/*`
4. Ensure root modules have explicit `role` in metadata

## 🎯 MODULE LIFECYCLE

### **Discovery Phase**
1. Scan filesystem for module directories
2. Read `default.nix` files
3. Extract `_module.metadata`
4. Generate `moduleConfig` objects

### **Config Phase**
1. Pass `moduleConfig` to each module
2. Modules access config via `lib.attrByPath`
3. Conditional imports based on `cfg.enable`

### **Build Phase**
1. Only enabled modules contribute to system config
2. Assertions validate configuration integrity
3. Final system builds with active modules

## 🎯 BEST PRACTICES

### **Module Authors**
- Always define complete `_module.metadata`
- Use `lib.attrByPath` for config access
- Add debug assertions during development
- Test with both enabled and disabled states

### **System Configurators**
- Understand scope × role implications
- Use `debug = true` during migration
- Verify core modules enable by default
- Explicitly enable desired optional modules

### **Maintainers**
- Validate metadata in CI/CD
- Keep scope × role matrix documented
- Monitor for assertion failures
- Update migration guides as needed
