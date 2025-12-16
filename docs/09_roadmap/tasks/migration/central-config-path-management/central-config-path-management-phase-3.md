# Central Config Path Management - Phase 3: Overlay System Implementation

## 🎯 Phase Overview

**Duration**: 3 days
**Focus**: Implement advanced config merging and conflict resolution
**Goal**: Enable sophisticated config overlay functionality with proper precedence

## 📋 Objectives

- [ ] Implement config overlay functionality with lib.mkMerge
- [ ] Create precedence resolution logic (system → shared → user)
- [ ] Add path-based restrictions for security
- [ ] Implement conflict detection and reporting

## 🔧 Implementation Steps

### Day 1: Config Overlay Core

#### 3.1 Create Config Overlay Module
**File**: `nixos/core/management/module-manager/lib/config-overlay.nix`

```nix
# Config overlay and merging functionality
{
  lib,
  ...
}:

let
  # Overlay precedence order (last wins)
  overlayOrder = ["system" "shared" "user"];

  # Forbidden paths for user configs (security restrictions)
  forbiddenUserPaths = [
    "desktop.displayManager"
    "hardware.gpu"
    "network.interfaces"
    "boot.loader"
    "services.xserver.displayManager"
  ];

  # Check if path is forbidden for user configs
  isForbiddenUserPath = path: userPaths:
    lib.any (forbidden: lib.hasPrefix forbidden path) userPaths;

  # Validate user config against restrictions
  validateUserConfig = userConfig: moduleName:
    let
      configPaths = lib.collect lib.isString (lib.attrNames (lib.flattenAttrs userConfig));
      forbiddenPaths = lib.filter (path: isForbiddenUserPath path forbiddenUserPaths) configPaths;
    in
      if forbiddenPaths != [] then
        throw "Module ${moduleName}: User config cannot set forbidden paths: ${lib.concatStringsSep ", " forbiddenPaths}"
      else
        userConfig;

  # Load configs from different sources with precedence
  loadOverlayConfigs = module: dimensions:
    let
      basePath = "/etc/nixos/configs";
      user = dimensions.user or null;
      hostname = dimensions.hostname or null;
      environment = dimensions.environment or null;

      # Config sources in precedence order (system first, user last)
      configSources = lib.flatten [
        # System config (always present)
        "${basePath}/system/${module.name}.nix"

        # Shared config (optional)
        (lib.optional (builtins.pathExists "${basePath}/shared/${module.name}.nix")
          "${basePath}/shared/${module.name}.nix")

        # User-specific config (highest precedence)
        (lib.optional (user != null &&
          builtins.pathExists "${basePath}/users/${user}/${module.name}.nix")
          "${basePath}/users/${user}/${module.name}.nix")

        # Host-specific override
        (lib.optional (hostname != null &&
          builtins.pathExists "${basePath}/hosts/${hostname}/${module.name}.nix")
          "${basePath}/hosts/${hostname}/${module.name}.nix")

        # Environment-specific override
        (lib.optional (environment != null &&
          builtins.pathExists "${basePath}/environments/${environment}/${module.name}.nix")
          "${basePath}/environments/${environment}/${module.name}.nix")
      ];

      # Load and validate each config
      loadConfig = path:
        let
          config = import path;
          isUserConfig = user != null && lib.hasInfix "/users/${user}/" path;
        in
          if isUserConfig
          then validateUserConfig config module.name
          else config;

      # Load all available configs
      loadedConfigs = map loadConfig (lib.filter builtins.pathExists configSources);

    in {
      configs = loadedConfigs;
      sources = configSources;
      merged = lib.mkMerge loadedConfigs;
    };

  # Detect potential conflicts in merged configs
  detectConflicts = mergedConfig:
    let
      # Find attributes that might conflict
      findConflicts = attrs: prefix:
        lib.flatten (lib.mapAttrsToList (name: value:
          let
            fullPath = if prefix == "" then name else "${prefix}.${name}";
          in
            if lib.isAttrs value && !lib.isDerivation value
            then findConflicts value fullPath
            else if lib.isFunction value
            then []  # Functions are handled by mkMerge
            else [{ path = fullPath; value = value; }]
        ) attrs);

      conflicts = findConflicts mergedConfig "";
      groupedConflicts = lib.groupBy (x: x.path) conflicts;

      # Report conflicts with multiple definitions
      actualConflicts = lib.filterAttrs (path: defs: builtins.length defs > 1) groupedConflicts;

    in
      if actualConflicts != {} then
        builtins.trace "CONFIG OVERLAY: Potential conflicts detected: ${builtins.toJSON (lib.attrNames actualConflicts)}" actualConflicts
      else
        {};

in {
  inherit
    overlayOrder
    forbiddenUserPaths
    isForbiddenUserPath
    validateUserConfig
    loadOverlayConfigs
    detectConflicts;
}
```

### Day 2: Integration with Config Resolver

#### 3.2 Update Config Resolver to Use Overlay
**File**: `nixos/core/management/module-manager/lib/config-resolver.nix`

```nix
# Updated config resolver with overlay support
{
  lib,
  config,
  ...
}:

let
  cfg = config.core.management.module-manager;
  configOverlay = import ./config-overlay.nix { inherit lib; };

  # Enhanced config resolution with overlay
  resolveConfigPaths = module: dimensions:
    let
      overlayResult = configOverlay.loadOverlayConfigs module dimensions;
    in {
      paths = overlayResult.sources;
      existingPaths = overlayResult.sources;
      strategy = "overlay";
      merged = overlayResult.merged;
      conflicts = configOverlay.detectConflicts overlayResult.merged;
    };

  # Load merged config with overlay logic
  loadMergedConfig = module: dimensions:
    let
      resolved = resolveConfigPaths module dimensions;
    in
      if cfg.resolutionMode == "merge" then
        resolved.merged
      else
        # Fallback to first config for exclusive mode
        lib.head (resolved.configs or [{}]);

in {
  # Export overlay functions
  inherit (configOverlay) overlayOrder forbiddenUserPaths validateUserConfig;

  # Enhanced resolution functions
  inherit resolveConfigPaths loadMergedConfig;
}
```

#### 3.3 Add Conflict Resolution Options
**File**: `nixos/core/management/module-manager/options.nix`

```nix
# Enhanced options for overlay system
{
  config,
  lib,
  ...
}:

{
  options.core.management.module-manager = {
    # Existing options...

    # Overlay configuration (NEW)
    overlay = {
      enable = lib.mkEnableOption "config overlay functionality";

      resolutionMode = lib.mkOption {
        type = lib.types.enum ["merge" "first"];
        default = "merge";
        description = "How to resolve conflicting config values";
      };

      conflictReporting = lib.mkOption {
        type = lib.types.enum ["silent" "warn" "error"];
        default = "warn";
        description = "How to handle config conflicts";
      };

      forbiddenUserPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "desktop.displayManager"
          "hardware.gpu"
          "network.interfaces"
          "boot.loader"
          "services.xserver.displayManager"
        ];
        description = "Configuration paths forbidden for user configs";
      };
    };
  };
}
```

### Day 3: Enhanced CLI and Validation

#### 3.4 Add CLI Commands for Overlay Management
**File**: `nixos/core/management/module-manager/commands.nix`

```nix
# Enhanced commands for overlay management
{
  config,
  lib,
  ...
}:

let
  cfg = config.core.management.module-manager;
  configResolver = import ./lib/config-resolver.nix { inherit lib config; };

in {
  # New overlay commands
  "config-overlay-status" = {
    description = "Show overlay status for all modules";
    script = ''
      echo "=== Config Overlay Status ==="
      echo "Resolution Mode: ${cfg.overlay.resolutionMode}"
      echo "Conflict Reporting: ${cfg.overlay.conflictReporting}"
      echo ""

      # List all modules with overlay info
      ${lib.concatStringsSep "\n" (map (module: ''
        echo "Module: ${module.name}"
        echo "  Scope: ${module.metadata.scope}"
        echo "  Mutability: ${module.metadata.mutability}"
        overlay_info="$(${configResolver.resolveConfigPaths module {}})"
        echo "  Config Sources: $(echo "$overlay_info" | jq -r '.paths | length')"
        echo ""
      '') (import ./lib/default.nix { inherit config lib; }).allModules)}
    '';
  };

  "config-validate-overlay" = {
    description = "Validate overlay configurations for conflicts";
    script = ''
      echo "=== Config Overlay Validation ==="

      # Validate each module's overlay config
      ${lib.concatStringsSep "\n" (map (module: ''
        echo "Validating ${module.name}..."
        conflicts="$(${configResolver.detectConflicts module {}})"
        if [ -n "$conflicts" ]; then
          echo "  ⚠️  Conflicts found: $conflicts"
        else
          echo "  ✅ No conflicts"
        fi
      '') (import ./lib/default.nix { inherit config lib; }).allModules)}
    '';
  };

  "config-show-precedence" = {
    description = "Show config precedence order";
    script = ''
      echo "=== Config Precedence Order ==="
      echo "1. System configs (/etc/nixos/configs/system/)"
      echo "2. Shared configs (/etc/nixos/configs/shared/)"
      echo "3. User configs (/etc/nixos/configs/users/\${user}/)"
      echo "4. Host configs (/etc/nixos/configs/hosts/\${hostname}/)"
      echo "5. Environment configs (/etc/nixos/configs/environments/\${env}/)"
      echo ""
      echo "Later sources override earlier ones when using merge mode."
    '';
  };
}
```

#### 3.5 Create Overlay Validation Utilities
**Nix validation** - Validation happens through Nix evaluation and module system.

```bash
#!/bin/bash
# Config overlay validation utilities

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Validate overlay configuration for a module
validate_overlay_config() {
    local module_name="$1"
    local user="${2:-}"

    echo "Validating overlay config for module: $module_name"

    # Check system config
    if [ -f "/etc/nixos/configs/system/$module_name.nix" ]; then
        echo -e "${GREEN}✓${NC} System config found"
    else
        echo -e "${YELLOW}⚠${NC} No system config found"
    fi

    # Check shared config
    if [ -f "/etc/nixos/configs/shared/$module_name.nix" ]; then
        echo -e "${GREEN}✓${NC} Shared config found"
    else
        echo -e "${YELLOW}⚠${NC} No shared config found"
    fi

    # Check user config
    if [ -n "$user" ] && [ -f "/etc/nixos/configs/users/$user/$module_name.nix" ]; then
        echo -e "${GREEN}✓${NC} User config found for $user"

        # Validate forbidden paths
        if grep -q "desktop\.displayManager\|hardware\.gpu\|network\.interfaces" "/etc/nixos/configs/users/$user/$module_name.nix"; then
            echo -e "${RED}✗${NC} User config contains forbidden paths!"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠${NC} No user config found"
    fi

    echo -e "${GREEN}✓${NC} Validation passed"
    return 0
}

# Main validation function
main() {
    local module="$1"
    local user="$2"

    if [ -z "$module" ]; then
        echo "Usage: $0 <module-name> [user]"
        exit 1
    fi

    validate_overlay_config "$module" "$user"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

## ✅ Success Criteria

- [ ] Config overlay functionality works correctly
- [ ] Precedence resolution follows correct order
- [ ] Path-based restrictions prevent security issues
- [ ] Conflict detection identifies potential issues
- [ ] CLI commands provide useful overlay information

## 🧪 Testing

### Unit Tests
- [ ] Test overlay merging with multiple config sources
- [ ] Test conflict detection and reporting
- [ ] Test path-based security restrictions

### Integration Tests
- [ ] Test full system rebuild with overlay configs
- [ ] Test user-specific config restrictions
- [ ] Test precedence order validation

## 📚 Documentation Updates

- [ ] Document overlay precedence rules
- [ ] Create security guidelines for user configs
- [ ] Update CLI command documentation

## 🔗 Next Steps

After completing Phase 3:
- Move to Phase 4: Implement migration and new strategies
- Test complex multi-user scenarios
- Validate security restrictions work correctly
