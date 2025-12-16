# Central Config Path Management in Module Manager - Implementation Plan

## 1. Project Overview

- **Feature/Component Name**: Central Config Path Management in Module Manager
- **Priority**: High
- **Category**: migration
- **Estimated Time**: 15 days
- **Dependencies**:
  - Current working module manager system
  - Existing config-loader system (to be enhanced)
  - NixOS flake structure
  - All system modules (audio, desktop, network, etc.)
- **Related Issues**: Hardcoded config paths in modules, inflexible folder structures, no user-specific configs
- **Created**: 2025-12-16T12:00:00.000Z

## 2. Technical Requirements

- **Tech Stack**: Nix, NixOS, bash, NixOS module system
- **Architecture Pattern**: Centralized config path resolver with multi-dimensional resolution (user/host/environment/shared/system)
- **Database Changes**: None (file-based config system)
- **API Changes**:
  - New module metadata schema (scope, mutability, dimensions)
  - Enhanced config resolution API
  - New CLI commands for config management
- **Frontend Changes**: None (system-level configuration)
- **Backend Changes**: Complete refactor of module discovery and config loading system

## 3. File Impact Analysis

#### Files to Modify:

- [ ] `nixos/core/management/module-manager/lib/discovery.nix` - Remove hardcoded configFile, add metadata schema
- [ ] `nixos/core/management/module-manager/lib/default.nix` - Add config path resolver functions
- [ ] `nixos/core/management/module-manager/module-manager-config.nix` - Add new config strategy options
- [ ] `nixos/core/management/module-manager/options.nix` - Add new configuration options
- [ ] `nixos/core/management/module-manager/commands.nix` - Add new CLI commands for config management
- [ ] `nixos/core/management/system-manager/lib/config-loader.nix` - Enhance with overlay/merge functionality
- [ ] `nixos/core/management/system-manager/lib/config-helpers.nix` - Add migration helpers
- [ ] `nixos/flake.nix` - Update config loading strategy
- [ ] All system module `default.nix` files - Remove configFile definitions, add metadata
- [ ] All system module `config.nix` files - Update to use centralized config paths

#### Files to Create:

- [ ] `nixos/core/management/module-manager/lib/config-resolver.nix` - New config path resolution logic
- [ ] `nixos/core/management/module-manager/lib/module-metadata.nix` - Module metadata schema and validation
- [ ] `nixos/core/management/module-manager/lib/config-overlay.nix` - Overlay/merge functionality
- [ ] `nixos/core/management/module-manager/lib/migration.nix` - Migration utilities
- [ ] `docs/09_roadmap/tasks/migration/central-config-path-management/central-config-path-management-phase-1.md` - Phase 1 implementation
- [ ] `docs/09_roadmap/tasks/migration/central-config-path-management/central-config-path-management-phase-2.md` - Phase 2 implementation
- [ ] `docs/09_roadmap/tasks/migration/central-config-path-management/central-config-path-management-phase-3.md` - Phase 3 implementation
- [ ] `docs/09_roadmap/tasks/migration/central-config-path-management/central-config-path-management-phase-4.md` - Phase 4 implementation
- [ ] `docs/09_roadmap/tasks/migration/central-config-path-management/central-config-path-management-phase-5.md` - Phase 5 implementation

#### Files to Delete:

- [ ] None (migration-focused task)

## 4. Implementation Phases

#### Phase 1: Foundations Setup (2 days)

- [ ] Create module metadata schema and validation
- [ ] Implement basic config path resolver
- [ ] Add new configuration options to module manager
- [ ] Create migration utility functions
- [ ] Set up categorized config directory structure

#### Phase 2: Module Discovery Refactor (3 days)

- [ ] Remove hardcoded configFile from all modules
- [ ] Add metadata to all system modules (scope, mutability, dimensions)
- [ ] Update module discovery to use centralized path resolution
- [ ] Implement dimension-based config resolution
- [ ] Add backward compatibility for existing configs

#### Phase 3: Overlay System Implementation (3 days)

- [ ] Implement config overlay/merge functionality (lib.mkMerge)
- [ ] Create precedence resolution logic (system → shared → user)
- [ ] Add conflict detection and resolution
- [ ] Implement path-based restrictions for user configs
- [ ] Add validation for forbidden user config paths

#### Phase 4: Migration & New Strategies (4 days)

- [ ] Implement categorized config structure (system/, shared/, users/)
- [ ] Enable NixOS-internal migration from flat to categorized structure
- [ ] Add multi-host and environment support
- [ ] Implement config caching for performance
- [ ] Add comprehensive validation and error handling

#### Phase 5: Testing & Documentation (3 days)

- [ ] Create comprehensive test suite for all config strategies
- [ ] Implement CLI tools for config management and debugging
- [ ] Add performance benchmarks and caching
- [ ] Create migration guides and documentation
- [ ] Test end-to-end migration scenarios

## 5. Code Standards & Patterns

- **Coding Style**: Nix coding standards, functional programming patterns, clear error handling
- **Naming Conventions**: camelCase for functions, descriptive names, consistent API
- **Error Handling**: Nix evaluation errors with descriptive messages, graceful degradation
- **Logging**: Structured tracing with builtins.trace, debug information for troubleshooting
- **Testing**: Unit tests for resolver functions, integration tests for full config loading
- **Documentation**: JSDoc-style comments, clear function documentation, usage examples

## 6. Security Considerations

- [ ] Input validation for config paths and metadata
- [ ] Path traversal protection in config resolution
- [ ] Permission validation for config file access
- [ ] Secure handling of user-specific config isolation
- [ ] Audit logging for config changes and migrations
- [ ] Protection against malicious config file injection

## 7. Performance Requirements

- **Response Time**: Config resolution < 100ms, system rebuild time unchanged
- **Throughput**: Handle 50+ modules efficiently
- **Memory Usage**: Minimal additional memory for caching
- **Database Queries**: None (file-based)
- **Caching Strategy**: In-memory caching for path resolution, optional persistent cache


## 9. Documentation Requirements

#### Code Documentation:

- [ ] JSDoc comments for all resolver functions and utilities
- [ ] Clear documentation of module metadata schema
- [ ] Usage examples for config overlay functionality
- [ ] Migration guide with before/after examples

#### User Documentation:

- [ ] Admin guide for new config structure
- [ ] Migration instructions for existing setups
- [ ] Troubleshooting guide for common config issues
- [ ] API reference for new CLI commands

## 10. Deployment Checklist

#### Pre-deployment:

- [ ] All unit and integration tests passing
- [ ] NixOS migration logic tested
- [ ] Backup of existing configs created
- [ ] Documentation reviewed and updated
- [ ] Security review completed

#### Deployment:

- [ ] Run NixOS-internal migration process
- [ ] Update module manager configuration
- [ ] Deploy new module manager version
- [ ] Restart system services if needed

#### Post-deployment:

- [ ] Verify system boots correctly
- [ ] Test user-specific config loading
- [ ] Monitor for config resolution errors
- [ ] Validate performance metrics

## 11. Rollback Plan

- [ ] NixOS rollback process to revert to flat config structure
- [ ] Restore backup of original config files
- [ ] Revert module manager to previous version
- [ ] Documentation of rollback procedure
- [ ] Communication plan for rollback scenarios

## 12. Success Criteria

- [ ] Modules no longer define config paths individually
- [ ] Module manager centrally manages all config paths
- [ ] All config strategies (flat, categorized, by-user) work correctly
- [ ] Migration from existing setups works smoothly
- [ ] Overlay/merge functionality works as expected
- [ ] Multi-dimensional config resolution (user/host/env) functional
- [ ] Performance requirements met
- [ ] All tests pass
- [ ] Documentation complete and accurate

## 13. Risk Assessment

#### High Risk:

- [ ] System becomes unbootable due to config resolution failures - Mitigation: Comprehensive testing, gradual rollout, backup systems
- [ ] Migration script corrupts existing configs - Mitigation: Atomic operations, comprehensive backups, dry-run mode
- [ ] Performance degradation in config resolution - Mitigation: Caching implementation, performance benchmarks

#### Medium Risk:

- [ ] Module metadata inconsistencies - Mitigation: Schema validation, automated checks
- [ ] Path resolution conflicts - Mitigation: Clear precedence rules, conflict detection
- [ ] User config isolation issues - Mitigation: Path-based restrictions, permission validation

#### Low Risk:

- [ ] CLI tool usability issues - Mitigation: User testing, clear error messages
- [ ] Documentation gaps - Mitigation: Comprehensive review process
- [ ] Edge cases in config overlay - Mitigation: Extensive test coverage

## 14. AI Auto-Implementation Instructions

#### AI Execution Context:

```json
{
  "requires_new_chat": true,
  "git_branch_name": "feature/central-config-path-management",
  "confirmation_keywords": ["fertig", "done", "complete"],
  "fallback_detection": true,
  "max_confirmation_attempts": 5,
  "timeout_seconds": 600
}
```

#### Success Indicators:

- [ ] All phases completed successfully
- [ ] System rebuilds without errors
- [ ] Config migration works correctly
- [ ] All modules load with new structure
- [ ] Tests pass
- [ ] Documentation updated

## 15. References & Resources

- **Technical Documentation**: ROADMAP.md - Central Config Path Management section
- **API References**: NixOS lib functions (mkMerge, recursiveUpdate), Nix builtins
- **Design Patterns**: Module system patterns, config resolution strategies
- **Best Practices**: NixOS configuration management, migration best practices
- **Similar Implementations**: Existing config-loader system, systemd unit resolution

---

## Phase Implementation Details

### Phase 1: Foundations Setup (2 days)
**Focus**: Create the core infrastructure for centralized config management

**Key Deliverables:**
- Module metadata schema with scope/mutability/dimensions
- Basic config path resolver with strategy support
- Enhanced module manager configuration options
- Migration utility framework

### Phase 2: Module Discovery Refactor (3 days)
**Focus**: Update all modules to use centralized path management

**Key Deliverables:**
- Remove hardcoded configFile from all modules
- Add proper metadata to system modules
- Update discovery logic to use resolver
- Maintain backward compatibility

### Phase 3: Overlay System Implementation (3 days)
**Focus**: Implement advanced config merging and conflict resolution

**Key Deliverables:**
- Config overlay functionality with lib.mkMerge
- Precedence resolution (system → shared → user)
- Path-based restrictions for security
- Conflict detection and reporting

### Phase 4: Migration & New Strategies (4 days)
**Focus**: Complete the migration to new config architecture

**Key Deliverables:**
- Categorized directory structure implementation
- Automated migration scripts
- Multi-dimensional config support (host/env)
- Performance optimizations and caching

### Phase 5: Testing & Documentation (3 days)
**Focus**: Validate the implementation and prepare for production

**Key Deliverables:**
- Comprehensive test suite
- CLI tools for config management
- Migration documentation
- Performance validation

---

**Total Implementation Time**: 15 days
**Risk Level**: High (architectural change)
**Testing Coverage**: 95%+ unit tests, full integration testing
**Documentation**: Complete migration and usage guides
