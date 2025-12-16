# Central Config Path Management - PURE Nix Implementation Plan

## 1. Project Overview

- **Feature/Component Name**: Central Config Path Management (Pure Nix Compatible)
- **Priority**: High
- **Category**: migration
- **Estimated Time**: 12 days
- **Dependencies**: Flake inputs, module manager, pure evaluation
- **Related Issues**: Config path management, pure Nix evaluation, module organization
- **Created**: 2024-12-16T12:00:00.000Z

## 2. Technical Requirements

- **Tech Stack**: Nix (pure evaluation), NixOS modules, flake inputs
- **Architecture Pattern**: Input-based resolver with pure path resolution
- **Database Changes**: None
- **API Changes**: Pure resolver functions
- **Frontend Changes**: None
- **Backend Changes**: Module manager with pure path handling

## ⚠️ **PURE NIX REQUIREMENTS**

### **CRITICAL: NO ABSOLUTE PATHS**
```nix
# ❌ FORBIDDEN (Impure)
baseConfigPath = "/etc/nixos/configs";

# ✅ ALLOWED (Pure)
baseConfigPath = inputs.configs;  # Via flake input
# OR
baseConfigPath = "./configs";     # Relative to flake
```

### **Flake Input Setup**
```nix
# flake.nix - MUST be configured
inputs.configs.url = "path:/etc/nixos/configs";
inputs.configs.flake = false;
```

## 3. File Impact Analysis

### Files to Modify:

- [ ] `nixos/flake.nix` - Ensure configs input exists
- [ ] `nixos/core/management/module-manager/module-manager-config.nix` - Add pure options
- [ ] `nixos/core/management/module-manager/lib/default.nix` - Export resolver

### Files to Create:

- [ ] `nixos/core/management/module-manager/lib/config-path-resolver.nix` - Pure resolver
- [ ] `nixos/core/management/module-manager/lib/config-merger.nix` - Pure merger
- [ ] `docs/09_roadmap/tasks/migration/central-config-path-management/central-config-path-management-pure-index.md` - Master index
- [ ] `docs/09_roadmap/tasks/migration/central-config-path-management/central-config-path-management-pure-phase-1.md` - Foundation
- [ ] `docs/09_roadmap/tasks/migration/central-config-path-management/central-config-path-management-pure-phase-2.md` - Core
- [ ] `docs/09_roadmap/tasks/migration/central-config-path-management/central-config-path-management-pure-phase-3.md` - Integration
- [ ] `docs/09_roadmap/tasks/migration/central-config-path-management/central-config-path-management-pure-phase-4.md` - Testing
- [ ] `docs/09_roadmap/tasks/migration/central-config-path-management/central-config-path-management-pure-phase-5.md` - Deployment

### Files to Delete:

- [ ] None (pure implementation)

## 4. Implementation Phases

### Phase 1: Pure Foundation (2 days)

- [ ] Verify flake inputs configuration
- [ ] Create config-path-resolver.nix with pure functions
- [ ] Add pure path options to module-manager
- [ ] Implement flat strategy with relative paths
- [ ] Basic pure evaluation tests

### Phase 2: Advanced Resolution (3 days)

- [ ] Implement categorized strategy
- [ ] Add dimension support (user, hostname, environment)
- [ ] Create config-merger.nix for pure merging
- [ ] Implement loadMergedConfig function
- [ ] Error handling and validation

### Phase 3: Module Integration (4 days)

- [ ] Update packages module to use resolver
- [ ] Update audio module to use resolver
- [ ] Update remaining 6 system modules
- [ ] Maintain backward compatibility
- [ ] Individual module testing

### Phase 4: Testing & Validation (2 days)

- [ ] Pure evaluation tests
- [ ] Integration tests with flake inputs
- [ ] Performance validation
- [ ] Documentation updates

### Phase 5: Deployment & Documentation (1 day)

- [ ] Full flake build validation
- [ ] Migration guide creation
- [ ] CLI command integration
- [ ] Final documentation review

## 5. Code Standards & Patterns

- **Coding Style**: Pure functions, no side effects, Nix best practices
- **Naming Conventions**: descriptive names, camelCase
- **Error Handling**: Pure error handling with either types
- **Testing**: Pure unit tests, no filesystem dependencies
- **Documentation**: Nixdoc comments, comprehensive examples

## 6. Security Considerations

- [ ] Path traversal protection in pure evaluation
- [ ] Input validation for all parameters
- [ ] No execution of external code
- [ ] Safe attribute access patterns

## 7. Performance Requirements

- **Response Time**: Path resolution < 50ms during evaluation
- **Memory Usage**: Minimal footprint
- **Evaluation Time**: No impact on flake evaluation speed

## 8. Testing Strategy

### Unit Tests (Pure):

- [ ] Path resolution functions
- [ ] Strategy implementations
- [ ] Config merging logic
- [ ] Error handling

### Integration Tests:

- [ ] Flake input integration
- [ ] Module loading with resolver
- [ ] Full system evaluation

## 9. Documentation Requirements

### Code Documentation:

- [ ] Nixdoc for all functions
- [ ] Usage examples in resolver
- [ ] API documentation

### User Documentation:

- [ ] Pure evaluation guide
- [ ] Migration from absolute paths
- [ ] Troubleshooting guide

## 10. Deployment Checklist

### Pre-deployment:

- [ ] All pure evaluation tests pass
- [ ] Flake inputs properly configured
- [ ] No absolute path usage

### Deployment:

- [ ] Flake evaluation succeeds
- [ ] System rebuild works
- [ ] Config loading functional

### Post-deployment:

- [ ] Performance monitoring
- [ ] Error log checking
- [ ] User feedback

## 11. Rollback Plan

- [ ] Revert to hardcoded paths in modules
- [ ] Remove resolver usage
- [ ] Restore old config loading

## 12. Success Criteria

- [ ] Pure Nix evaluation compatible
- [ ] All strategies work with flake inputs
- [ ] All modules updated successfully
- [ ] No performance regression
- [ ] Full backward compatibility

## 13. Risk Assessment

### High Risk:

- [ ] Pure evaluation compatibility - Mitigation: Extensive testing, no absolute paths

### Medium Risk:

- [ ] Flake input complexity - Mitigation: Clear documentation, validation

### Low Risk:

- [ ] Module update complexity - Mitigation: Incremental approach

## 14. AI Auto-Implementation Instructions

### AI Execution Context:

```json
{
  "requires_new_chat": false,
  "git_branch_name": "feature/pure-config-path-management",
  "confirmation_keywords": ["fertig", "done", "complete"],
  "fallback_detection": true,
  "max_confirmation_attempts": 3,
  "timeout_seconds": 300
}
```

### Success Indicators:

- [ ] All phases completed
- [ ] Pure evaluation works
- [ ] No build errors
- [ ] All tests pass

## 15. References & Resources

- **Technical Documentation**: Nix manual, flake documentation
- **API References**: NixOS module system
- **Design Patterns**: Pure functional programming in Nix
- **Best Practices**: Nix flake best practices, pure evaluation guidelines
- **Similar Implementations**: Existing config-loader.nix (adapted for pure usage)
