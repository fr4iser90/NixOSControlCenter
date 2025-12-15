# Config Loader to Single File - Master Index

## 📋 Task Overview
- **Name**: Config Loader to Single File
- **Category**: migration
- **Priority**: High
- **Status**: Planning
- **Total Estimated Time**: 6 hours
- **Created**: 2025-12-15T12:00:00.000Z
- **Last Updated**: 2025-12-15T12:00:00.000Z

## 📁 File Structure
```
docs/09_roadmap/tasks/migration/config-loader-to-single-file/
├── config-loader-to-single-file-index.md (this file)
├── config-loader-to-single-file-implementation.md
├── config-loader-to-single-file-phase-1.md
├── config-loader-to-single-file-phase-2.md
└── config-loader-to-single-file-phase-3.md
```

## 🎯 Main Implementation
- **[Config Loader to Single File Implementation](./config-loader-to-single-file-implementation.md)** - Complete implementation plan and specifications

## 📊 Phase Breakdown
| Phase | File | Status | Time | Progress |
|-------|------|--------|------|----------|
| 1 | [Phase 1](./config-loader-to-single-file-phase-1.md) | Pending | 2h | 0% |
| 2 | [Phase 2](./config-loader-to-single-file-phase-2.md) | Pending | 3h | 0% |
| 3 | [Phase 3](./config-loader-to-single-file-phase-3.md) | Pending | 1h | 0% |

## 🔄 Subtask Management
### Active Subtasks
- [ ] Create consolidated system-config.nix with ALL required paths
- [ ] Fix ALL module configurations to read from correct systemConfig paths
- [ ] Remove config-loader from flake.nix
- [ ] Test system rebuild with ALL modules
- [ ] Verify CLI tools still work
- [ ] Verify configHelpers still work for hardware detection

### Completed Subtasks
- [x] Create directory structure
- [x] Update implementation plan with ALL affected files

### Pending Subtasks
- [ ] Implement Phase 1: Create complete system-config.nix
- [ ] Implement Phase 2: Fix all module configs + flake.nix
- [ ] Implement Phase 3: Test everything works

## 📈 Progress Tracking
- **Overall Progress**: 10% Complete
- **Current Phase**: Phase 1 - Planning
- **Next Milestone**: system-config.nix created
- **Estimated Completion**: 2025-12-15

## 🔗 Related Tasks
- **Dependencies**: None
- **Dependents**: System stability
- **Related**: Config management simplification

## 📝 Notes & Updates
### 2025-12-15 - Task Created
- Initial planning for config-loader removal
- Focus: Only remove config-loader, keep everything else unchanged
- Goal: One system-config.nix file with all configurations

## 🚀 Quick Actions
- [View Implementation Plan](./config-loader-to-single-file-implementation.md)
- [Start Phase 1](./config-loader-to-single-file-phase-1.md)
- [Review Progress](#progress-tracking)
- [Update Status](#notes--updates)
