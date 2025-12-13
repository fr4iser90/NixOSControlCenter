# Task 4: Testing, Validation & CLI Enhancement

## 🎯 Goal
Create comprehensive testing suite, schema validation, and enhanced CLI tools for the new config management system.

## 📋 Description
Implement thorough testing, config validation, and user-friendly CLI commands to ensure the system is robust, validated, and easy to use.

## ✅ Acceptance Criteria
- [ ] Full test suite (unit + integration + migration)
- [ ] Schema validation for all configs
- [ ] Enhanced CLI commands working
- [ ] Documentation updated
- [ ] CI integration ready
- [ ] Performance benchmarks pass

## 🔧 Implementation Details

### 4.1 Comprehensive Testing Suite

#### Unit Tests (Nix)
```nix
# tests/unit/resolver-tests.nix
{
  testResolvePrecedence = {
    expr = resolveConfigPath "packages" { user = "fr4iser"; };
    expected = "/etc/nixos/configs/users/fr4iser/packages-config.nix";
  };

  testResolveFallback = {
    expr = resolveConfigPath "audio" { user = "fr4iser"; };
    expected = "/etc/nixos/configs/system/audio-config.nix";
  };
}
```

#### Integration Tests (Shell + Nix)
- Multi-user setup simulation
- Migration end-to-end tests
- Permission validation
- Performance benchmarks

#### Migration Tests
- Dry-run accuracy
- Atomic operations
- Rollback completeness
- Error recovery

### 4.2 Schema Validation
```nix
# lib/validation.nix
configSchema = {
  audio = {
    enable = lib.types.bool;
    system = lib.types.enum ["pipewire" "pulseaudio"];
  };
  packages = {
    packageModules = lib.types.listOf lib.types.str;
  };
};

validateConfig = path: schema:
  let config = import path;
  in lib.attrsets.validateConfig schema config;
```

### 4.3 Enhanced CLI Commands (via NCC API)
```bash
# Enhanced ncc module-manager commands
ncc module-manager list --strategy=categorized          # Show all resolved paths
ncc module-manager create-config audio --for-user=fr4iser  # Generate template
ncc module-manager validate /etc/nixos/configs/        # Validate all configs
ncc module-manager diff module audio                   # Show path resolution details
ncc module-manager set-strategy categorized --apply    # Change strategy safely
ncc module-manager status                              # Show system status
```

### 4.4 Documentation Updates
- Update all architecture docs
- Create migration guide
- CLI reference documentation
- Troubleshooting guide

## 🧪 Testing Checklist
- [ ] Unit: Path resolution for all strategies
- [ ] Unit: Metadata loading and validation
- [ ] Integration: Multi-user scenarios
- [ ] Integration: Migration dry-run vs actual
- [ ] Integration: Rollback functionality
- [ ] Performance: Caching vs non-caching
- [ ] Security: Permission validation
- [ ] Schema: Config validation accuracy

## 📅 Dependencies
- Task 1, 2, 3 (all previous tasks completed)

## ⏱️ Estimated Duration
3-4 days

## 📁 Files to Create/Modify
- `tests/unit/` - Unit test files
- `tests/integration/` - Integration tests
- `nixos/core/management/module-manager/lib/validation.nix` - Schema validation
- `nixos/core/management/module-manager/commands/` - CLI commands
- `docs/` - Updated documentation
- `ci/` - CI integration files

## 🎯 Final Integration
After completion:
- Full system ready for production use
- All components tested and validated
- Documentation complete
- Ready for roadmap Phase 5 implementation
