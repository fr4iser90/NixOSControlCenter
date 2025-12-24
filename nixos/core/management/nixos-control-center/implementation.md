# NixOS Control Center - Architecture Implementation Plan

## Executive Summary

Based on the fundamental architecture analysis, this implementation plan addresses the key issues:

1. **NCC System Module Creation** - Separate CLI ecosystem from system management
2. **Formatting Migration** - Move CLI formatting to dedicated NCC module
3. **Permission System Integration** - Role-based access control for CLI commands
4. **Validated Module Discovery** - Add validation during module discovery phase
5. **Enhanced Validation Pipeline** - Coordinate validation between System and Module managers
6. **Domain Layer Evaluation** - Assess impact of removing rigid domain structure

## Implementation Phases

### Phase 1: NCC System Module Foundation (2-3 days)

#### 1.1 Create NCC Module Structure
**Objective:** Establish the new NCC system module with proper metadata and API structure.

**Files to Create:**
```
core/management/nixos-control-center/
├── default.nix                                  # Main NCC module definition
├── options.nix                                  # NCC configuration options
├── config.nix                                   # NCC implementation
├── commands.nix                                 # NCC command registration
├── api.nix                                      # Public NCC APIs for other modules
└── submodules/
    ├── cli-formatter/                           # MOVED from system-manager
    │   ├── default.nix                          # Module definition with metadata
    │   ├── api.nix                              # API exports
    │   ├── options.nix                          # NCC submodule options
    │   ├── config.nix                           # Implementation
    │   ├── colors.nix                           # MOVED from system-manager
    │   ├── core.nix                             # MOVED from system-manager
    │   ├── status.nix                           # MOVED from system-manager
    │   └── cli-formatter-config.nix             # User configuration template
    ├── cli-registry/                            # Command registration system
    │   ├── default.nix                          # Module definition with metadata
    │   ├── api.nix                              # API exports
    │   ├── options.nix                          # NCC submodule options
    │   ├── config.nix                           # Implementation
    │   ├── commands.nix                         # Command registration
    │   ├── filter.nix                           # Permission-aware filtering
    │   └── cli-registry-config.nix              # User configuration template
    └── cli-permissions/                         # Role-based access control
        ├── default.nix                          # Module definition with metadata
        ├── api.nix                              # API exports
        ├── options.nix                          # NCC submodule options
        ├── config.nix                           # Implementation
        ├── roles.nix                            # Permission roles
        ├── policies.nix                         # Permission policies
        ├── access-control.nix                   # Access checking logic
        ├── user-context.nix                     # Current user detection
        └── cli-permissions-config.nix           # User configuration template
```

**Implementation Steps:**
1. Create directory structure with submodules
2. Copy cli-formatter components from system-manager to ncc/submodules/cli-formatter/
3. Create cli-registry submodule with command registration logic
4. Create cli-permissions submodule with role-based access control
5. Update metadata in all submodules following MODULE_TEMPLATE.md
6. Create API exports within NCC module structure

#### 1.2 Update Core Imports
**Objective:** Add NCC module to core/default.nix

**Files to Modify:**
- `nixos/core/default.nix`

**Changes:**
```nix
imports = [
  # Core system modules
  ./base/boot
  ./base/hardware
  ./base/network
  ./base/localization
  ./base/user
  ./base/desktop
  ./base/audio
  ./base/packages
  # Management (includes infrastructure as submodules)
  ./management/system-manager
  ./management/module-manager
  ./management/nixos-control-center             # CLI ecosystem (NEW)
];
```

#### 1.3 NCC Module Definition
**File:** `nixos/core/management/nixos-control-center/default.nix`
```nix
{ config, lib, pkgs, systemConfig, ... }:

let
  # Module metadata (REQUIRED - define directly here)
  metadata = {
    # Basic info
    role = "core";                    # "core" | "optional"
    name = "nixos-control-center";    # Unique module identifier
    description = "NixOS Control Center - CLI ecosystem";
    category = "core";                # "core" | "base" | "security" | "infrastructure" | "specialized"
    subcategory = "management";       # Specific subcategory within category
    stability = "stable";             # "stable" | "experimental" | "deprecated" | "beta" | "alpha"
    version = "1.0.0";                # SemVer: MAJOR.MINOR.PATCH
  };
in {
  # REQUIRED: Export metadata for discovery system
  _module.metadata = metadata;

  # Module imports
  imports = [
    ./options.nix
    ./config.nix
    ./commands.nix
    ./api.nix
  ];
}
```

#### 1.4 NCC API Definition
**File:** `nixos/core/management/nixos-control-center/api.nix`
```nix
{ config, lib, ... }:

with lib;

let
  # Import APIs using generic API system
  formatter = config.${getModuleApi "cli-formatter"};
  registry = config.${getModuleApi "cli-registry"};
  permissions = config.${getModuleApi "cli-permissions"};
in {
  # Public NCC API - available to all modules
  core.management.nixos-control-center.api = {
    inherit formatter registry permissions;

    # Convenience functions
    format = formatter;
    registerCommand = registry.register;
  };
}
```

### Phase 2: Formatting Migration (1-2 days)

#### 2.1 Update System Manager Commands
**Objective:** Change system-manager to use NCC formatting API instead of direct imports

**Files to Modify:**
- `nixos/core/management/system-manager/commands.nix`

**Changes:**
```nix
# BEFORE: Direct imports
colors = import ./submodules/cli-formatter/colors.nix;
coreFormatter = import ./submodules/cli-formatter/core { inherit lib colors; config = {}; };
statusFormatter = import ./submodules/cli-formatter/status { inherit lib colors; config = {}; };

# AFTER: Use generic API system
formatter = config.${getModuleApi "cli-formatter"};
colors = formatter.colors;
coreFormatter = formatter.core;
statusFormatter = formatter.status;
```

#### 2.2 Update Module Manager Commands
**Objective:** Update module-manager to use NCC formatting API

**Files to Modify:**
- `nixos/core/management/module-manager/commands.nix`

**Changes:**
```nix
# BEFORE: Direct system-manager reference
ui = getModuleApi "cli-formatter";

# AFTER: Keep build-time access (context-appropriate)
ui = getModuleApi "cli-formatter";
```

#### 2.3 Remove Old CLI Formatter from System Manager
**Objective:** Remove the old cli-formatter submodule from system-manager

**Files to Modify:**
- `nixos/core/management/system-manager/default.nix`
- Remove cli-formatter references from imports and config

#### 2.4 Update Flake.nix
**Objective:** Ensure NCC module is properly imported in flake structure

**Files to Modify:**
- `nixos/flake.nix`

**Verification:**
- Test that all NCC commands still work
- Verify formatting consistency across modules

### Phase 3: Validated Module Discovery (2-3 days)

#### 3.1 Create Discovery Validation Library
**Objective:** Implement module validation during discovery phase

**Files to Create:**
```
core/management/module-manager/lib/
├── discovery.nix           # Enhanced discovery with validation
├── validation.nix          # Module structure validation
└── metadata.nix            # Metadata processing utilities
```

**Implementation:**
```nix
# lib/discovery.nix - Enhanced discovery with validation
{ lib, ... }:

let
  validateModule = modulePath: {
    hasDefault = builtins.pathExists (modulePath + "/default.nix");
    hasMetadata = hasDefault && ((import modulePath)._module.metadata or null) != null;
    isValid = hasDefault && hasMetadata;
  };

  discoverModules = basePath:
    let
      entries = lib.filterAttrs (name: type: type == "directory") (builtins.readDir basePath);
      validatedModules = lib.mapAttrs (name: _: validateModule (basePath + "/${name}")) entries;
      validModules = lib.filterAttrs (name: validation: validation.isValid) validatedModules;
    in
    lib.attrNames validModules;
in {
  inherit discoverModules validateModule;
}
```

#### 3.2 Update Module Manager Config
**Objective:** Integrate validated discovery into module manager

**Files to Modify:**
- `nixos/core/management/module-manager/config.nix`

**Changes:**
- Import new discovery library
- Replace simple directory scanning with validated discovery
- Add error reporting for invalid modules

#### 3.3 Add Discovery Commands
**Objective:** Add CLI commands to validate and report module status

**Files to Modify:**
- `nixos/core/management/module-manager/commands.nix`

**New Commands:**
- `ncc module-manager validate-modules` - Check all modules for validity
- `ncc module-manager list-invalid` - Show modules that failed validation

### Phase 4: Enhanced Validation Pipeline (1-2 days)

#### 4.1 Extend NCC with Validation APIs
**Objective:** Add validation coordination to NCC as CLI infrastructure

**Files to Modify:**
- `core/management/nixos-control-center/api.nix` - Add validation APIs

**New NCC Validation APIs:**
```nix
core.management.nixos-control-center.api = {
  inherit formatter registry;

  # Validation APIs
  validation = {
    validateModule = moduleName: { /* validation logic */ };
    validateSystem = { /* system checks */ };
    checkDependencies = moduleList: { /* dependency resolution */ };
    reportIssues = issues: { /* NCC-formatted error reporting */ };
  };
};
```

#### 4.2 System Manager Validation Enhancement
**Objective:** Make system manager use NCC validation APIs

**Files to Modify:**
- `nixos/core/management/system-manager/submodules/system-checks/`

**Changes:**
- Use `config.${getModuleApi "nixos-control-center"}.validation` instead of local logic
- Format validation reports with NCC formatter

#### 4.3 Module Manager Validation Enhancement
**Objective:** Integrate module manager with NCC validation

**Files to Modify:**
- `nixos/core/management/module-manager/handlers/module-manager.nix`

**Changes:**
- Use NCC validation APIs for dependency checking
- Report validation results through NCC formatting

### Phase 3: Permission System Integration (2-3 days)

#### 3.1 Extend NCC with Permission APIs
**Objective:** Add role-based access control to NCC as core CLI infrastructure

**Files to Create/Modify:**
```
core/management/nixos-control-center/
├── submodules/
│   └── permissions/          # NEW: Permission management
│       ├── default.nix       # Permission module
│       ├── roles.nix         # Role definitions
│       ├── policies.nix      # Permission policies
│       ├── access-control.nix # Access checking logic
│       └── user-context.nix  # Current user detection
```

**Permission Architecture:**
```nix
# submodules/permissions/roles.nix
{
  # Standard roles (extend existing user roles)
  roles = {
    admin = {
      description = "Full system access";
      permissions = [ "system.*" "module.*" "security.*" ];
      inherits = [];
    };

    virtualization = {
      description = "Virtualization and container management";
      permissions = [ "infrastructure.homelab.*" "infrastructure.vm.*" ];
      inherits = [];
    };

    user = {
      description = "Basic user access";
      permissions = [ "system.status" "module.list" ];
      inherits = [];
    };
  };
}
```

#### 3.2 Update CLI Registry with Permissions
**Objective:** Add permission metadata to command registration

**Files to Modify:**
- `core/management/nixos-control-center/submodules/cli-registry/commands.nix`

**Enhanced Command Structure:**
```nix
# NEW: Commands with permission metadata
commands = [
  {
    name = "homelab-status";
    script = "${homelabStatus}/bin/nixos-control-center-homelab-status";
    description = "Show homelab status";
    category = "infrastructure";
    permissions = {
      roles = [ "admin" "virtualization" ];  # Required roles
      users = [];                           # Specific users (optional)
      groups = [];                          # Group membership (optional)
    };
  }
];
```

#### 3.3 Create Permission-Aware Command Filter
**Objective:** Filter commands based on user permissions

**Files to Create:**
- `core/management/nixos-control-center/submodules/cli-registry/filter.nix`

**Implementation:**
```nix
# filter.nix - Permission-aware command filtering
{ config, lib, ... }:
let
  cfg = config.${getModuleApi "cli-registry"};
  permissions = config.${getModuleApi "cli-permissions"};

  # Get current user context
  currentUser = permissions.user-context.currentUser;

  # Check if user has permission for command
  hasPermission = command: user:
    let
      cmdPerms = command.permissions or {};
      userRoles = permissions.getUserRoles user;
      userGroups = permissions.getUserGroups user;
    in
      # Allow if no permissions defined (backward compatibility)
      if cmdPerms == {} then true
      else
        # Check roles
        (cmdPerms.roles or [] == []) ||
        (lib.any (role: builtins.elem role userRoles) cmdPerms.roles) ||
        # Check specific users
        (builtins.elem user (cmdPerms.users or [])) ||
        # Check groups
        (lib.any (group: builtins.elem group userGroups) (cmdPerms.groups or []));

  # Filter commands based on permissions
  filterCommands = commands: user:
    builtins.filter (cmd: hasPermission cmd user) commands;

in {
  # Public API
  inherit hasPermission filterCommands;
}
```

#### 3.4 Update NCC API with Permissions
**Objective:** Expose permission functionality through NCC API

**Files to Modify:**
- `core/management/nixos-control-center/api.nix`

**Enhanced NCC API:**
```nix
core.management.nixos-control-center.api = {
  inherit formatter registry;

  # NEW: Permission APIs
  permissions = {
    checkAccess = user: command: config.${getModuleApi "cli-permissions"}.access-control.checkAccess user command;
    filterCommands = user: commands: config.${getModuleApi "cli-permissions"}.cli-filter.filterCommands commands user;
    getUserRoles = username: config.${getModuleApi "cli-permissions"}.user-context.getUserRoles username;
    getUserGroups = username: config.${getModuleApi "cli-permissions"}.user-context.getUserGroups username;
  };

  # Validation APIs
  validation = {
    validateModule = moduleName: { /* validation logic */ };
    validateSystem = { /* system checks */ };
    checkDependencies = moduleList: { /* dependency resolution */ };
    reportIssues = issues: { /* NCC-formatted error reporting */ };
  };
};
```

#### 3.5 Update NCC Commands with Permission Filtering
**Objective:** Make NCC CLI commands respect permissions

**Files to Modify:**
- `core/management/nixos-control-center/commands.nix`

**Implementation:**
```nix
# commands.nix - Permission-aware command help
{ config, lib, pkgs, ... }:
let
  cfg = config.${getModuleApi "nixos-control-center"};
  permissions = config.${getModuleApi "cli-permissions"};
  registry = config.${getModuleApi "cli-registry"};

  # Get current user (from environment or detection)
  currentUser = permissions.user-context.currentUser;

  # Filter available commands for current user
  availableCommands = permissions.cli-filter.filterCommands registry.commands currentUser;

  # Permission-aware help command
  nccHelp = pkgs.writeShellScriptBin "ncc" ''
    #!${pkgs.bash}/bin/bash
    echo "NixOS Control Center (NCC) - Available Commands:"
    echo "User: $(whoami) | Roles: ${permissions.getUserRoles currentUser}"
    echo ""

    ${lib.concatStringsSep "\n" (map (cmd: ''
      echo "${cmd.name} - ${cmd.description}"
    '') availableCommands)}

    echo ""
    echo "Use 'ncc <command> --help' for detailed help"
  '';

in {
  # Register permission-filtered NCC command
  environment.systemPackages = [ nccHelp ];
}
```

### Phase 4: Validated Module Discovery (2-3 days)

#### 4.1 Create Discovery Validation Library

#### 5.1 Analyze Current Domain Usage
**Objective:** Assess impact of domain removal

**Analysis Tasks:**
1. Map all current modules to domains
2. Identify cross-domain dependencies
3. Survey user expectations for organization
4. Evaluate metadata-driven alternatives

#### 5.2 Create Migration Path
**Objective:** Plan domain layer removal if beneficial

**Files to Create:**
- `docs/migration/domain-removal-plan.md`

**Migration Strategy:**
1. Add metadata fields to all modules
2. Implement metadata-driven discovery
3. Update documentation and examples
4. Provide migration script for users

#### 5.3 Implement Metadata-Driven Discovery (Optional)
**Objective:** If domains are removed, implement flexible categorization

**Files to Modify:**
- `core/management/module-manager/lib/discovery.nix`

**Implementation:**
```nix
# Metadata-driven grouping
groupByCategory = modules:
  lib.groupBy (module: module._module.metadata.category or "uncategorized") modules;
```
## Success Criteria

### Functional Requirements
- [ ] NCC module provides formatting API to all modules
- [ ] Permission system filters commands by user roles
- [ ] CLI shows only accessible commands per user
- [ ] Module discovery validates module structure
- [ ] Validation coordinator prevents invalid configurations
- [ ] System and Module managers coordinate properly
- [ ] CLI commands work with new architecture

### Quality Requirements
- [ ] All existing functionality preserved
- [ ] Permission system is backward compatible
- [ ] No breaking changes without migration path
- [ ] Comprehensive test coverage
- [ ] Updated documentation
- [ ] Clear permission error messages

### Performance Requirements
- [ ] Module discovery time < 2 seconds
- [ ] Permission checking < 100ms per command
- [ ] Validation overhead < 10% of build time
- [ ] CLI responsiveness maintained

## Timeline and Milestones

| Phase | Duration | Milestone |
|-------|----------|-----------|
| Phase 1: NCC Foundation | 2-3 days | NCC module created and integrated |
| Phase 2: Formatting Migration | 1-2 days | All modules use NCC formatting |
| Phase 3: Permission System | 2-3 days | Role-based command access control |
| Phase 4: Validated Discovery | 2-3 days | Module validation during discovery |
| Phase 5: Validation Pipeline | 2-3 days | Centralized validation coordination |

**Total Timeline:** 13-19 days

## Dependencies and Prerequisites

### Required Knowledge
- Nix language and NixOS module system
- Current system-manager and module-manager architecture
- CLI command structure and registry system

### Tools and Environment
- NixOS development environment
- Access to test systems for validation
- Version control for safe rollbacks

### Pre-Implementation Checklist
- [ ] All current tests passing
- [ ] Backup of current working configuration
- [ ] Review of MODULE_TEMPLATE.md compliance
- [ ] Documentation of current CLI command structure

## Next Steps

1. **Immediate:** Review and approve implementation plan
2. **Week 1:** Start Phase 1 (NCC module creation)
3. **Ongoing:** Regular testing and validation checkpoints
4. **Final:** Production deployment with monitoring

---

*This implementation plan transforms the architecture from scattered concerns to a well-organized, maintainable system with clear separation of responsibilities.*
