# 📚 PRACTICAL EXAMPLES

*For architecture concepts, see [ARCHITECTURE.md](ARCHITECTURE.md). For API details, see [REFERENCE.md](REFERENCE.md).*

## 🎯 COMPLETE EXAMPLES

### **Complete Metadata Template:**

```nix
# EVERY module needs this complete metadata in default.nix:
{ config, lib, pkgs, systemConfig, ... }:
{
  _module.metadata = {
    # ESSENTIAL for default control
    role = "internal";  # "internal" | "optional" (Default: "internal")

    # BASIC INFORMATION
    name = "my-module";
    description = "Description of what this module does";

    # VERSIONING
    version = "1.0.0";

    # CATEGORIZATION (for UI/Docs)
    category = "system";        # system | management | infrastructure | security | specialized
    subcategory = "logging";    # e.g. audio, network, security, etc.

    # DEPENDENCIES
    dependencies = [
      "system-checks"    # Other modules that are required
      "command-center"
    ];

    # TAGS for search/filter (optional)
    tags = [
      "monitoring"
      "logging"
      "system"
    ];

    # SUPPORT LEVEL (optional)
    stability = "stable";      # stable | beta | experimental | deprecated
    maintainer = "team-core";   # For support requests
  };

  # Rest of module definition...
}
```

## 🎯 EXAMPLES FOR DIFFERENT ROLES

### **Internal Submodule (Default):**
```nix
_module.metadata = {
  role = "internal";  # Default for submodules
  name = "cli-formatter";
  description = "Formats CLI output consistently";
  # ... additional fields
};
```

### **Optional Submodule:**
```nix
_module.metadata = {
  role = "optional";  # Explicitly optional
  name = "debug-logging";
  description = "Enhanced debug logging (performance impact)";
  stability = "experimental";
  # ... additional fields
};
```

### **Module (always optional):**
```nix
_module.metadata = {
  role = "internal";  # Irrelevant for modules, always false
  name = "ssh-client-manager";
  description = "SSH client configuration and management";
  category = "security";
  # ... additional fields
};
```

## 🎯 WORKING MODULE EXAMPLE

### **Complete Core Module Example:**
```nix
# core/base/desktop/default.nix
{ config, lib, pkgs, systemConfig, moduleConfig, ... }:
let
  cfg = lib.attrByPath
    (lib.splitString "." moduleConfig.configPath)
    { enable = moduleConfig.defaultEnable; }  # = true (core/internal)
    systemConfig;
in {
  _module.metadata = {
    role = "internal";
    name = "desktop";
    description = "Desktop environment configuration";
    category = "system";
    subcategory = "desktop";
  };

  imports = if cfg.enable then [
    ./desktop.nix  # Actual desktop config
  ] else [];

  # Optional debug assertions
  assertions = lib.optionals (config.debug or false) [
    {
      assertion = lib.hasAttrByPath
        (lib.splitString "." moduleConfig.configPath)
        systemConfig;
      message = "Missing desktop config path: ${moduleConfig.configPath}";
    }
  ];
}
```

### **Complete Module Example:**
```nix
# modules/security/ssh-client-manager/default.nix
{ config, lib, pkgs, systemConfig, moduleConfig, ... }:
let
  cfg = lib.attrByPath
    (lib.splitString "." moduleConfig.configPath)
    { enable = moduleConfig.defaultEnable; }  # = false (module scope)
    systemConfig;
in {
  _module.metadata = {
    role = "internal";  # Not relevant for default calculation
    name = "ssh-client-manager";
    description = "SSH client configuration and management";
    category = "security";
    stability = "stable";
  };

  imports = if cfg.enable then [
    ./ssh-config.nix
    ./key-management.nix
  ] else [];

  # Module-specific options
  options.modules.security.ssh-client-manager = {
    enable = lib.mkEnableOption "SSH client management";
    defaultKeyType = lib.mkOption {
      type = lib.types.enum [ "ed25519" "rsa" ];
      default = "ed25519";
      description = "Default SSH key type";
    };
  };

  config = lib.mkIf cfg.enable {
    # Actual SSH configuration
    programs.ssh = {
      enable = true;
      # ... SSH config
    };
  };
}
```

## 🎯 CONFIGURATION EXAMPLES

### **User Configuration (systemConfig):**
```nix
# systemConfig.modules.security.ssh-client-manager
{
  enable = true;
  defaultKeyType = "ed25519";
}

# systemConfig.core.base.desktop
{
  enable = true;  # This is actually redundant since core/internal defaults to true
}
```

### **Generated moduleConfig Example:**
```nix
# For modules/security/ssh-client-manager/
{
  configPath = "modules.security.ssh-client-manager";
  apiPath = "modules.security.ssh-client-manager";
  scope = "module";
  role = "internal";
  metadata = { /* full metadata */ };
  defaultEnable = false;
}
```

## 🎯 DEBUGGING EXAMPLES

### **Debug Assertions:**
```nix
# Enable debug mode to catch missing configs
{
  debug = true;  # This will enable assertions in all modules
}
```

### **Common Errors & Solutions:**

**Error:** `assertion 'Root module 'my-module' must define explicit 'role' in _module.metadata!' failed`
**Solution:** Add `role = "internal";` or `role = "optional";` to your root module's `_module.metadata`

**Error:** `Missing config path: core.base.desktop`
**Solution:** Ensure your `systemConfig` has the expected structure or check your path generation

**Error:** Module not loading despite `enable = true`
**Solution:** Check that the module's scope/role combination produces the expected `defaultEnable` value
