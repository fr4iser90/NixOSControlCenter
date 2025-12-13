# Task 3: Extend Existing Migration System for Categorized Configs

## 🎯 Goal
Extend the existing automatic migration system to handle categorized config paths (system/, shared/, users/).

## 📋 Description
**CRITICAL DISCOVERY**: The codebase already has a sophisticated migration system! We need to extend it, not replace it. The system can already migrate v0→v1.0 automatically with schema validation, atomic operations, and backups.

## ✅ Acceptance Criteria
- [ ] Existing migration system extended for categorized paths
- [ ] Module configs migrate to correct categories (system/, shared/, users/)
- [ ] Backward compatibility maintained during transition
- [ ] Schema validation works with new categorized structure

## 🔧 Implementation Details

### 3.1 Extend Migration Schema
The existing system uses migration plans like `v0-to-v1.nix`. We need to extend it to handle categorized paths.

### 3.2 Update Migration Logic
Modify the existing migration engine to place configs in the correct categories based on module metadata.

### 3.3 Integration with Module Metadata
Use the module metadata from Task 1 to determine where each module's config should go.

## 📁 Existing Migration System (Already Implemented!)
- **Location**: `nixos/core/management/system-manager/components/config-migration/`
- **Features**:
  - Automatic v0→v1.0 migration
  - Schema validation
  - Atomic operations with backups
  - Chain migration support
  - jq-based transformations

## 🧪 Testing
- [ ] Migration places configs in correct categories
- [ ] Existing migration functionality still works
- [ ] Backward compatibility maintained

## 📅 Dependencies
- Task 1 (Module Metadata System) - for category determination
- Task 2 (Config Path Resolver) - for path resolution

## ⏱️ Estimated Duration
2-3 days (extending existing system)

## 📁 Files to Modify
- `nixos/core/management/system-manager/components/config-migration/migration.nix`
- `nixos/core/management/system-manager/components/config-migration/schema/migrations/v1-to-v2.nix` (new)
- `nixos/core/management/system-manager/components/config-migration/schema/v2.nix` (new)

## 🎯 Next Steps
After completion, the existing migration system will automatically handle categorized configs.
# Task 3: Extend Existing Migration System for Categorized Configs

## 🎯 Goal
Extend the existing automatic migration system to handle categorized config paths (system/, shared/, users/).

## 📋 Description
**CRITICAL DISCOVERY**: The codebase already has a sophisticated migration system! We need to extend it, not replace it. The system can already migrate v0→v1.0 automatically with schema validation, atomic operations, and backups.

## ✅ Acceptance Criteria
- [ ] Existing migration system extended for categorized paths
- [ ] Module configs migrate to correct categories (system/, shared/, users/)
- [ ] Backward compatibility maintained during transition
- [ ] Schema validation works with new categorized structure

## 🔧 Implementation Details

### 3.1 Extend Migration Schema
The existing system uses migration plans like `v0-to-v1.nix`. We need to extend it to handle categorized paths.

### 3.2 Update Migration Logic
Modify the existing migration engine to place configs in the correct categories based on module metadata.

### 3.3 Integration with Module Metadata
Use the module metadata from Task 1 to determine where each module's config should go.

## 📁 Existing Migration System (Already Implemented!)
- **Location**: `nixos/core/management/system-manager/components/config-migration/`
- **Features**:
  - Automatic v0→v1.0 migration
  - Schema validation
  - Atomic operations with backups
  - Chain migration support
  - jq-based transformations

## 🧪 Testing
- [ ] Migration places configs in correct categories
- [ ] Existing migration functionality still works
- [ ] Backward compatibility maintained

## 📅 Dependencies
- Task 1 (Module Metadata System) - for category determination
- Task 2 (Config Path Resolver) - for path resolution

## ⏱️ Estimated Duration
2-3 days (extending existing system)

## 📁 Files to Modify
- `nixos/core/management/system-manager/components/config-migration/migration.nix`
- `nixos/core/management/system-manager/components/config-migration/schema/migrations/v1-to-v2.nix` (new)
- `nixos/core/management/system-manager/components/config-migration/schema/v2.nix` (new)

## 🎯 Next Steps
After completion, the existing migration system will automatically handle categorized configs.
