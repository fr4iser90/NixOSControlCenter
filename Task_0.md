# Module Rename Plan

## Current Module Structure Analysis
After analyzing all 22 modules, we identified that several modules are actually managers (actively managing resources) but are missing the "-manager" suffix. According to NixOS naming conventions, only true manager modules should have this suffix.

## Renames to Implement

### Infrastructure Features
- `nixos/features/infrastructure/bootentry/` → `nixos/features/infrastructure/bootentry-manager/`
- `nixos/features/infrastructure/homelab/` → `nixos/features/infrastructure/homelab-manager/`

### Security Features
- `nixos/features/security/ssh-client/` → `nixos/features/security/ssh-client-manager/`
- `nixos/features/security/ssh-server/` → `nixos/features/security/ssh-server-manager/`

### System Features
- `nixos/features/system/lock/` → `nixos/features/system/lock-manager/`

## Reasoning
These modules actively manage resources:
- **bootentry**: Manages boot entries dynamically
- **homelab**: Manages Docker containers and services
- **ssh-client**: Manages SSH connections and keys
- **ssh-server**: Manages SSH access and configurations
- **lock**: Manages system locks and backups

Following NixOS conventions, manager modules get the "-manager" suffix to indicate they actively control/manipulate other components rather than just providing passive configuration.