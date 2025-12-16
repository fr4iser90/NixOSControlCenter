# Central Config Path Management - Master Index

## 📋 Task Overview

- **Name**: Central Config Path Management in Module Manager
- **Category**: migration
- **Priority**: High
- **Status**: Planning - Plan Corrected
- **Total Estimated Time**: 15 days
- **Created**: 2025-12-16T12:00:00.000Z
- **Last Updated**: 2025-12-16T12:00:00.000Z
- **Validation Status**: ✅ Complete - Plan Corrected (High Confidence)
- **Implementation Readiness**: Plan Corrected, Ready for Implementation

## 📁 File Structure

```
docs/09_roadmap/tasks/migration/central-config-path-management/
├── central-config-path-management-index.md (this file)
├── central-config-path-management-implementation.md
├── central-config-path-management-phase-1.md
├── central-config-path-management-phase-2.md
├── central-config-path-management-phase-3.md
├── central-config-path-management-phase-4.md
└── central-config-path-management-phase-5.md
```

## 🎯 Main Implementation

- **[Implementation Plan](./central-config-path-management-implementation.md)** - Complete technical specification and implementation roadmap

## 📊 Phase Breakdown

| Phase | File | Status | Time | Progress |
|-------|------|--------|------|----------|
| 1 | [Config-Helpers Enhancement](./central-config-path-management-phase-1.md) | Ready | 3 days | 0% |
| 2 | [Module Integration](./central-config-path-management-phase-2.md) | Pending | 4 days | 0% |
| 3 | [Advanced Features](./central-config-path-management-phase-3.md) | Pending | 4 days | 0% |
| 4 | [CLI & Testing](./central-config-path-management-phase-4.md) | Pending | 4 days | 0% |

## 🔄 Subtask Management

### Active Subtasks

- [ ] Create module metadata schema
- [ ] Implement config path resolver
- [ ] Update module discovery logic
- [ ] Add overlay/merge functionality
- [ ] Create migration scripts

### Completed Subtasks

- [x] Task planning and documentation structure created

### Pending Subtasks

- [ ] Phase 1 implementation
- [ ] Phase 2 implementation
- [ ] Phase 3 implementation
- [ ] Phase 4 implementation
- [ ] Phase 5 implementation

## 📈 Progress Tracking

- **Overall Progress**: 10% Complete (Planning & Validation Corrected)
- **Current Phase**: Planning → Plan Corrected
- **Next Milestone**: Phase 1 implementation start (Config-Helpers Enhancement)
- **Estimated Completion**: 15 days from implementation start
- **Validation Date**: 2025-12-16T12:00:00.000Z
- **Last Plan Correction**: 2025-12-16T12:00:00.000Z
- **Risk Level**: Medium (evolutionary enhancement)
- **Confidence Level**: High (correct architectural approach)

## 🔗 Related Tasks

- **Dependencies**:
  - Current working module manager system
  - Existing config-loader infrastructure
- **Dependents**:
  - Future multi-user config features
  - Advanced config management features
- **Related**:
  - `automation/module-config-centralization` - Related config management improvements
  - `migration/config-loader-to-single-file` - Config consolidation efforts
  - **Shell Setup Scripts** - Will be updated to save directly in v1 structure (separate task)

## 📝 Notes & Updates

### 2025-12-16 - Plan Correction Complete ✅

- **Critical Discovery**: Config-helpers.nix is the core system - must be enhanced, not replaced
- **Plan Correction**: Changed from "replace config-helpers" to "enhance config-helpers"
- **New Approach**: Evolutionary enhancement maintaining default config creation
- **Risk Reduction**: Medium risk (evolutionary) vs High risk (replacement)
- **Next Steps**: Ready for Phase 1 (Config-Helpers Enhancement)

### 2025-12-16 - Task Validation Complete ✅

- **Architecture Assessment**: Current system has solid foundation with config-helpers
- **Implementation Plan**: Original 5-phase approach corrected to 4-phase evolutionary approach
- **Gap Analysis**: Identified config-helpers enhancement needed instead of replacement
- **Risk Assessment**: Medium risk, well-mitigated by evolutionary approach
- **Next Steps**: Plan corrected, ready for proper implementation

### 2025-12-16 - Task Created

- Created comprehensive implementation plan for central config path management
- Defined 5-phase implementation approach with detailed technical specifications
- Set up task structure with index and implementation files
- Estimated total implementation time: 15 days

### Future Updates

- Phase completion status updates
- Implementation progress tracking
- Issue resolution notes
- Performance benchmark results

## 🚀 Quick Actions

- [View Implementation Plan](./central-config-path-management-implementation.md)
- [Start Phase 1](./central-config-path-management-phase-1.md)
- [Review Progress](#progress-tracking)
- [Update Status](#notes--updates)

---

## 📋 Task Summary

This task implements **centralized config path management** for the NixOS Control Center module manager, moving from hardcoded per-module config paths to a flexible, centrally-managed system supporting:

- **Categorized config structure** (system/, shared/, users/)
- **Multi-dimensional resolution** (user, host, environment)
- **Config overlay/merging** instead of "first wins" precedence
- **Flexible folder strategies** for different deployment scenarios

**Key Benefits:**
- No more hardcoded config paths in individual modules
- Support for user-specific and environment-specific configs
- Clean separation between system, shared, and user configurations
- Extensible architecture for future enhancements

**Implementation Approach:**
- 5-phase approach over 15 days
- Maintains backward compatibility during migration
- NixOS-internal migration (no separate scripts needed)
- Shell setup scripts updated separately to save in v1 structure

**Risk Mitigation:**
- Gradual rollout with extensive testing
- Automated backup and rollback capabilities
- Comprehensive validation at each phase
- Performance monitoring and optimization
