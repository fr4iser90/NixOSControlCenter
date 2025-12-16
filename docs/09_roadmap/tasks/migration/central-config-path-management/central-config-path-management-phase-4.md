# Central Config Path Management - Phase 4: Migration & New Strategies

## 🎯 Phase Overview

**Duration**: 4 days
**Focus**: Complete the migration to new config architecture
**Goal**: Enable categorized directory structure and advanced features

## 📋 Objectives

- [ ] Implement categorized config structure (system/, shared/, users/)
- [ ] Implement NixOS-internal migration logic
- [ ] Add multi-host and environment support
- [ ] Implement caching for performance
- [ ] Add comprehensive validation and error handling

## 🔧 Implementation Steps

### Day 1: Categorized Directory Structure

#### 4.1 Create Directory Structure Setup
**Nix-side setup** - Directory structure creation and validation through Nix module system. Migration happens automatically during nixos-rebuild.

```bash
#!/bin/bash
# Automated migration script for central config path management

set -e

# Configuration
BASE_PATH="/etc/nixos/configs"
BACKUP_DIR="/etc/nixos/configs.backup.$(date +%Y%m%d_%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Create categorized directory structure
create_directories() {
    log_info "Creating categorized directory structure..."

    # System directories
    mkdir -p "$BASE_PATH/system"
    mkdir -p "$BASE_PATH/shared"
    mkdir -p "$BASE_PATH/users"
    mkdir -p "$BASE_PATH/hosts"
    mkdir -p "$BASE_PATH/environments"

    # User-specific directories (from module manager config)
    if command -v nixos-rebuild &> /dev/null; then
        # Try to get managed users from current config
        MANAGED_USERS=$(nix eval --raw -f /etc/nixos/system-config.nix 'config.core.management.module-manager.managedUsers' 2>/dev/null || echo '["fr4iser"]')
        for user in $(echo "$MANAGED_USERS" | jq -r '.[]' 2>/dev/null || echo "fr4iser"); do
            mkdir -p "$BASE_PATH/users/$user"
        done
    else
        mkdir -p "$BASE_PATH/users/fr4iser"
    fi

    log_success "Directory structure created"
}

# Backup existing configs
backup_configs() {
    log_info "Creating backup of existing configs..."

    if [ -d "$BASE_PATH" ]; then
        cp -r "$BASE_PATH" "$BACKUP_DIR"
        log_success "Backup created at: $BACKUP_DIR"
    else
        log_warn "No existing configs to backup"
    fi
}

# Migrate flat config structure to categorized
migrate_flat_configs() {
    log_info "Migrating flat config structure to categorized..."

    # Define module categorizations
    declare -A MODULE_CATEGORIES=(
        ["audio"]="system"
        ["boot"]="system"
        ["desktop"]="system"
        ["hardware"]="system"
        ["localization"]="system"
        ["network"]="system"
        ["packages"]="shared"
    )

    # Find all *-config.nix files
    find "$BASE_PATH" -maxdepth 1 -name "*-config.nix" | while read -r config_file; do
        filename=$(basename "$config_file")
        module_name="${filename%-config.nix}"

        # Determine category
        category="${MODULE_CATEGORIES[$module_name]}"
        if [ -z "$category" ]; then
            category="system"  # Default fallback
            log_warn "Unknown module '$module_name', defaulting to 'system' category"
        fi

        # New path
        new_file="$BASE_PATH/$category/$module_name.nix"

        # Move file
        if [ ! -f "$new_file" ]; then
            mv "$config_file" "$new_file"
            log_info "Migrated: $filename → $category/$module_name.nix"
        else
            log_warn "Target already exists, skipping: $new_file"
        fi
    done

    log_success "Migration completed"
}

# Validate migration
validate_migration() {
    log_info "Validating migration..."

    local errors=0

    # Check that all expected directories exist
    for dir in system shared users hosts environments; do
        if [ ! -d "$BASE_PATH/$dir" ]; then
            log_error "Missing directory: $BASE_PATH/$dir"
            ((errors++))
        fi
    done

    # Check that old flat files are gone
    if find "$BASE_PATH" -maxdepth 1 -name "*-config.nix" | grep -q .; then
        log_error "Some old config files still exist in flat structure"
        ((errors++))
    fi

    if [ $errors -eq 0 ]; then
        log_success "Migration validation passed"
        return 0
    else
        log_error "Migration validation failed with $errors errors"
        return 1
    fi
}

# Main migration function
main() {
    local dry_run=false
    local force=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run) dry_run=true ;;
            --force) force=true ;;
            --help)
                echo "Usage: $0 [--dry-run] [--force]"
                echo "  --dry-run: Show what would be done without making changes"
                echo "  --force: Skip confirmation prompts"
                exit 0
                ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
        shift
    done

    echo "=== NixOS Central Config Migration ==="
    echo "This will migrate your config structure from flat to categorized."
    echo "A backup will be created automatically."
    echo ""

    if [ "$dry_run" = false ] && [ "$force" = false ]; then
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Migration cancelled"
            exit 0
        fi
    fi

    if [ "$dry_run" = true ]; then
        log_info "DRY RUN MODE - No changes will be made"
    fi

    create_directories
    if [ "$dry_run" = false ]; then
        backup_configs
        migrate_flat_configs
        validate_migration
    fi

    log_success "Migration script completed successfully"
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

#### 4.2 Add Migration Commands to Module Manager
**File**: `nixos/core/management/module-manager/commands.nix`

```nix
# Add migration commands
"migrate-config-central" = {
  description = "Migrate to central config path management";
  script = ''
    echo "Starting central config migration..."
    echo "Migration happens automatically during nixos-rebuild."
    echo "Existing configs will be moved to categorized structure."
  '';
};

"migrate-config-dry-run" = {
  description = "Show what migration would do without making changes";
  script = ''
    echo "Migration dry run:"
    echo "Run: nixos-rebuild dry-build"
    echo "This will show what configs would be migrated."
  '';
};

"migrate-config-validate" = {
  description = "Validate current config structure";
  script = ''
    echo "Validating config structure..."
    echo "Use 'nixos-rebuild build' for automatic validation"
  '';
};
```

### Day 2: Multi-Host and Environment Support

#### 4.3 Extend Config Resolver for Advanced Dimensions
**File**: `nixos/core/management/module-manager/lib/config-resolver.nix`

```nix
# Enhanced resolver with full dimension support
{
  lib,
  config,
  ...
}:

let
  cfg = config.core.management.module-manager;

  # Full dimension resolution
  resolveFullDimensions = dimensions:
    let
      user = dimensions.user or cfg.managedUsers or [];
      hostname = dimensions.hostname or config.networking.hostName or null;
      environment = dimensions.environment or cfg.defaultEnvironment or "production";
    in {
      inherit user hostname environment;
    };

  # Advanced path resolution with all dimensions
  resolveAdvancedPaths = module: dimensions:
    let
      dims = resolveFullDimensions dimensions;
      basePath = cfg.baseConfigPath;

      # Build path candidates in precedence order
      pathCandidates = lib.flatten [
        # 1. User + Host + Environment (most specific)
        (lib.optional (dims.user != [] && dims.hostname != null && dims.environment != null)
          "${basePath}/users/${lib.head dims.user}/hosts/${dims.hostname}/environments/${dims.environment}/${module.name}.nix")

        # 2. User + Host
        (lib.optional (dims.user != [] && dims.hostname != null)
          "${basePath}/users/${lib.head dims.user}/hosts/${dims.hostname}/${module.name}.nix")

        # 3. User + Environment
        (lib.optional (dims.user != [] && dims.environment != null)
          "${basePath}/users/${lib.head dims.user}/environments/${dims.environment}/${module.name}.nix")

        # 4. Host + Environment
        (lib.optional (dims.hostname != null && dims.environment != null)
          "${basePath}/hosts/${dims.hostname}/environments/${dims.environment}/${module.name}.nix")

        # 5. User-specific
        (lib.optional (dims.user != [])
          "${basePath}/users/${lib.head dims.user}/${module.name}.nix")

        # 6. Host-specific
        (lib.optional (dims.hostname != null)
          "${basePath}/hosts/${dims.hostname}/${module.name}.nix")

        # 7. Environment-specific
        (lib.optional (dims.environment != null)
          "${basePath}/environments/${dims.environment}/${module.name}.nix")

        # 8. Shared (fallback)
        "${basePath}/shared/${module.name}.nix"

        # 9. System (base defaults)
        "${basePath}/system/${module.name}.nix"
      ];

      # Filter to existing paths
      existingPaths = builtins.filter builtins.pathExists pathCandidates;

    in {
      paths = pathCandidates;
      existingPaths = existingPaths;
      dimensions = dims;
      resolved = if existingPaths != [] then lib.head existingPaths else null;
    };

  # Load config with full dimension support
  loadDimensionConfig = module: dimensions:
    let
      resolved = resolveAdvancedPaths module dimensions;
      configs = map (path: import path) resolved.existingPaths;
    in
      if cfg.overlay.enable
      then (import ./config-overlay.nix { inherit lib; }).loadOverlayConfigs module dimensions
      else lib.mkMerge configs;

in {
  inherit
    resolveFullDimensions
    resolveAdvancedPaths
    loadDimensionConfig;
}
```

### Day 3: Performance Optimization and Caching

#### 4.4 Implement Config Caching
**File**: `nixos/core/management/module-manager/lib/config-cache.nix`

```nix
# Config caching for performance optimization
{
  lib,
  config,
  ...
}:

let
  cfg = config.core.management.module-manager;

  # Cache key generation
  generateCacheKey = module: dimensions:
    let
      dims = lib.generators.toJSON dimensions;
      key = "${module.name}-${module.version}-${builtins.hashString "sha256" dims}";
    in
      builtins.substring 0 32 key;  # First 32 chars

  # In-memory cache (during system build)
  configCache = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = {};
    internal = true;
  };

  # Cache config resolution
  getCachedConfig = module: dimensions:
    let
      cacheKey = generateCacheKey module dimensions;
      cached = configCache.${cacheKey} or null;
    in
      if cached != null && cfg.enableCaching then
        builtins.trace "CONFIG CACHE: Hit for ${module.name}" cached
      else
        let
          resolved = (import ./config-resolver.nix { inherit lib config; }).loadMergedConfig module dimensions;
          newCache = configCache // { ${cacheKey} = resolved; };
        in
          builtins.trace "CONFIG CACHE: Miss for ${module.name}" resolved;

  # Cache statistics
  getCacheStats = let
    totalEntries = builtins.length (lib.attrNames configCache);
    hitRate = 0;  # Would need more sophisticated tracking
  in {
    entries = totalEntries;
    hitRate = hitRate;
    enabled = cfg.enableCaching;
  };

  # Clear cache (for debugging)
  clearCache = {
    configCache = {};
  };

in {
  inherit
    getCachedConfig
    getCacheStats
    clearCache
    generateCacheKey;
}
```

#### 4.5 Add Performance Monitoring
**File**: `nixos/core/management/module-manager/commands.nix`

```nix
# Add performance monitoring commands
"config-cache-stats" = {
  description = "Show config caching statistics";
  script = ''
    cache_stats="$(${import ./lib/config-cache.nix { inherit lib config; }).getCacheStats})"
    echo "=== Config Cache Statistics ==="
    echo "Enabled: $(echo "$cache_stats" | jq -r '.enabled')"
    echo "Cache Entries: $(echo "$cache_stats" | jq -r '.entries')"
    echo "Hit Rate: $(echo "$cache_stats" | jq -r '.hitRate')%"
  '';
};

"config-performance-test" = {
  description = "Run performance tests for config resolution";
  script = ''
    echo "=== Config Resolution Performance Test ==="
    echo "Testing rebuild time with new config system..."
    time nixos-rebuild build --no-build-output >/dev/null 2>&1
  '';
};
```

### Day 4: Comprehensive Validation and Error Handling

#### 4.6 Enhanced Error Handling
**File**: `nixos/core/management/module-manager/lib/error-handling.nix`

```nix
# Comprehensive error handling for config system
{
  lib,
  ...
}:

let
  # Config error types
  configErrors = {
    MISSING_CONFIG = "MISSING_CONFIG";
    INVALID_SYNTAX = "INVALID_SYNTAX";
    FORBIDDEN_PATH = "FORBIDDEN_PATH";
    CONFLICT_DETECTED = "CONFLICT_DETECTED";
    PERMISSION_DENIED = "PERMISSION_DENIED";
    INVALID_METADATA = "INVALID_METADATA";
  };

  # Create structured error
  makeConfigError = type: message: details: {
    error = true;
    type = type;
    message = message;
    details = details;
    timestamp = builtins.currentTime;
  };

  # Handle config loading errors
  safeLoadConfig = path: default:
    let
      result = builtins.tryEval (import path);
    in
      if result.success then
        result.value
      else
        builtins.trace "CONFIG ERROR: Failed to load ${path}: ${result.value}" default;

  # Validate config structure
  validateConfigStructure = config: moduleName:
    if !lib.isAttrs config then
      makeConfigError configErrors.INVALID_SYNTAX
        "Config for ${moduleName} must be an attribute set"
        { path = "root"; expected = "attrs"; actual = builtins.typeOf config; }
    else
      null;  # No error

  # Comprehensive validation
  validateFullConfig = module: config: dimensions:
    let
      structureErrors = validateConfigStructure config module.name;
      # Add more validations as needed
    in
      lib.filter (x: x != null) [structureErrors];

  # Error reporting
  formatError = error:
    let
      typeStr = error.type or "UNKNOWN";
      msg = error.message or "Unknown error";
      details = if error.details or {} != {} then
        "\nDetails: ${builtins.toJSON error.details}"
      else "";
    in
      "[${typeStr}] ${msg}${details}";

in {
  inherit
    configErrors
    makeConfigError
    safeLoadConfig
    validateConfigStructure
    validateFullConfig
    formatError;
}
```

#### 4.7 Final Integration and Testing
**File**: `nixos/core/management/module-manager/lib/default.nix`

```nix
# Final integration of all components
{
  config,
  lib,
  pkgs,
  systemConfig,
  ...
}:

let
  # Import all libraries
  discovery = import ./discovery.nix { inherit lib; };
  configResolver = import ./config-resolver.nix { inherit lib config; };
  configOverlay = import ./config-overlay.nix { inherit lib; };
  configCache = import ./config-cache.nix { inherit lib config; };
  errorHandling = import ./error-handling.nix { inherit lib; };
  moduleMetadata = import ./module-metadata.nix { inherit lib; };

  # Unified config resolution with error handling
  resolveModuleConfigSafe = module: dimensions:
    let
      result = builtins.tryEval (configResolver.loadMergedConfig module dimensions);
    in
      if result.success then
        let
          config = result.value;
          validationErrors = errorHandling.validateFullConfig module config dimensions;
        in
          if validationErrors == [] then
            config
          else
            builtins.trace "CONFIG VALIDATION ERRORS: ${lib.concatStringsSep "; " (map errorHandling.formatError validationErrors)}" config
      else
        builtins.trace "CONFIG RESOLUTION ERROR: ${result.value}" {};

in {
  # Core functionality
  inherit resolveModuleConfigSafe;

  # All sub-modules
  inherit
    discovery
    configResolver
    configOverlay
    configCache
    errorHandling
    moduleMetadata;

  # Utility functions with error handling
  allModulesWithConfigs = dimensions:
    map (module: module // {
      resolvedConfig = resolveModuleConfigSafe module dimensions;
    }) discovery.discoverAllModules;
}
```

## ✅ Success Criteria

- [ ] Categorized directory structure works correctly
- [ ] NixOS-internal migration logic works correctly
- [ ] Multi-host and environment configs load properly
- [ ] Performance caching improves resolution speed
- [ ] Comprehensive validation catches all error types


## 📚 Documentation Updates

- [ ] Complete migration guide for users
- [ ] Performance tuning documentation
- [ ] Multi-host setup instructions

## 🔗 Next Steps

After completing Phase 4:
- Move to Phase 5: Final testing and documentation
- Validate all functionality works end-to-end
- Prepare for production deployment
