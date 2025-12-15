# Config Loader to Single File Implementation

## 1. Project Overview
- **Feature/Component Name**: Config Loader to Single File Migration
- **Priority**: High
- **Category**: migration
- **Estimated Time**: 6 hours
- **Dependencies**: Current working system with config-loader
- **Related Issues**: Config management simplification
- **Created**: 2025-12-15T12:00:00.000Z

## 2. Technical Requirements
- **Tech Stack**: Nix, NixOS
- **Architecture Pattern**: Simplified config loading
- **Database Changes**: None
- **API Changes**: None
- **Frontend Changes**: None
- **Backend Changes**: Config loading mechanism

## 3. File Impact Analysis

#### Files to Modify:
- [ ] `nixos/flake.nix` - Remove config-loader, direct systemConfig import
- [ ] `nixos/system-config.nix` - Create new consolidated config file
- [ ] `nixos/core/system/hardware/config.nix` - Replace configHelpers with direct config
- [ ] `nixos/core/system/boot/config.nix` - Replace configHelpers with direct config
- [ ] `nixos/core/system/audio/config.nix` - Replace configHelpers with direct config
- [ ] `nixos/core/system/desktop/config.nix` - Replace configHelpers with direct config
- [ ] `nixos/core/system/localization/config.nix` - Replace configHelpers with direct config
- [ ] `nixos/core/system/network/config.nix` - Replace configHelpers with direct config
- [ ] `nixos/core/system/packages/config.nix` - Replace configHelpers with direct config
- [ ] `nixos/core/system/user/config.nix` - Replace configHelpers with direct config
- [ ] `nixos/core/management/module-manager/config.nix` - Keep for CLI functionality
- [ ] `nixos/core/management/system-manager/config.nix` - Keep for CLI functionality
- [ ] `nixos/core/management/system-manager/submodules/cli-registry/config.nix` - Keep
- [ ] `nixos/core/management/system-manager/submodules/cli-formatter/config.nix` - Keep
- [ ] `nixos/core/management/system-manager/submodules/system-update/config.nix` - Keep
- [ ] `nixos/core/management/system-manager/submodules/system-logging/config.nix` - Keep
- [ ] `nixos/core/management/system-manager/submodules/system-checks/config.nix` - Keep

#### Files to Create:
- [ ] `nixos/system-config.nix` - Consolidated configuration file with ALL module configs

#### Files to Delete:
- [ ] `nixos/core/management/system-manager/lib/config-loader.nix` - Config loader obsolete

## 4. Implementation Phases

#### Phase 1: Create Consolidated Config (2 hours)
- [ ] Collect ALL configuration templates (*-config.nix files)
- [ ] Create single system-config.nix with ALL required attribute paths
- [ ] Include system.*, core.management.*, and submodule paths
- [ ] Ensure proper Nix syntax and structure for ALL modules

#### Phase 2: Fix Modules & Remove Config Loader (3 hours)
- [ ] Fix ALL system module configs to read from correct systemConfig paths
- [ ] Keep management modules unchanged for CLI functionality
- [ ] Remove configLoader import from flake.nix
- [ ] Replace with direct systemConfig import
- [ ] Delete config-loader.nix file

#### Phase 3: Test & Verify (1 hour)
- [ ] Test system rebuild with ALL modules
- [ ] Verify CLI tools still work completely
- [ ] Confirm configHelpers still work for hardware detection
- [ ] Verify ALL configurations load correctly

## 5. Code Standards & Patterns
- **Coding Style**: Nix standard formatting
- **Naming Conventions**: camelCase for attributes
- **Error Handling**: Nix error propagation
- **Logging**: Built-in Nix tracing
- **Testing**: Manual testing with nixos-rebuild
- **Documentation**: Nix comments

## 6. Security Considerations
- [ ] No security implications - internal config changes only

## 7. Performance Requirements
- **Response Time**: Same as current system
- **Throughput**: N/A
- **Memory Usage**: Same or better
- **Database Queries**: N/A
- **Caching Strategy**: N/A

## 8. Testing Strategy

#### Unit Tests:
- Manual verification of config loading

#### Integration Tests:
- Full system rebuild testing

#### E2E Tests:
- Complete system boot and functionality test

## 9. Documentation Requirements
- [ ] Update comments in system-config.nix
- [ ] Document new single-file approach

## 10. Deployment Checklist
- [ ] system-config.nix created and populated
- [ ] Config loader removed from flake.nix
- [ ] config-loader.nix deleted
- [ ] Test rebuild successful

## 11. Rollback Plan
- Restore config-loader in flake.nix
- Restore config-loader.nix file

## 12. Success Criteria
- [ ] System rebuilds successfully
- [ ] All configurations loaded from single file
- [ ] configHelpers still work for automatic hardware detection
- [ ] No config-loader references remain

## 13. Risk Assessment

#### High Risk:
- System becomes unbootable - Mitigation: Keep backup of working config-loader

#### Medium Risk:
- Configuration errors - Mitigation: Test rebuild before final switch

#### Low Risk:
- Missing configurations - Mitigation: Verify all templates included

## 14. AI Auto-Implementation Instructions

```json
{
  "requires_new_chat": false,
  "git_branch_name": "feature/config-loader-to-single-file",
  "confirmation_keywords": ["fertig", "done", "complete"],
  "fallback_detection": true,
  "max_confirmation_attempts": 3,
  "timeout_seconds": 300
}
```

## 15. References & Resources
- Current config-loader implementation
- All *-config.nix template files
- NixOS module system documentation
