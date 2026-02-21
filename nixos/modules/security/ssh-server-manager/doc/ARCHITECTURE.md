# SSH Server Manager - Architecture

## Overview

High-level architecture description of the SSH Server Manager module.

## Components

### Module Structure

```
ssh-server-manager/
├── README.md                    # Module overview
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic
├── template-config.nix          # Default configuration template
├── commands.nix                 # CLI commands
├── auth.nix                   # Authentication management
├── monitoring.nix               # Monitoring functionality
├── notifications.nix            # Notification system
└── scripts/                     # Management scripts
```

### Command Structure

| Command | Purpose | Who Uses It |
|---------|---------|-------------|
| `ssh-request-access` | Request temporary SSH access | End users |
| `ssh-approve-request` | Approve access requests | Administrators |
| `ssh-deny-request` | Deny access requests | Administrators |
| `ssh-list-requests` | View all requests | Administrators |
| `ssh-grant-access` | Direct access grant (emergency) | Administrators |
| `ssh-cleanup-requests` | Clean up old requests | Administrators |

### Workflow Types

#### 1. Request/Approval Workflow (Recommended)
```
User Request → Request Stored → Admin Notified → Admin Decision → Access Granted/Denied
```

#### 2. Direct Grant Workflow (Emergency)
```
Admin Grant → Access Enabled → Auto-Disable Timer
```

## Design Decisions

### Decision 1: Request-Based Access Control

**Context**: Need secure, auditable SSH access management
**Decision**: Request/approval workflow with audit trail
**Rationale**: Security, compliance, accountability
**Alternatives**: Direct access (rejected - no audit trail)

### Decision 2: Automatic SSH Config Management

**Context**: Need to manage SSH config securely
**Decision**: Automatic backup and revert of SSH config
**Rationale**: Prevents permanent security weakening
**Trade-offs**: Requires backup management, but essential for security

## Data Flow

```
User Request → Request Storage → Notification → Admin Decision → SSH Config Update → Auto-Disable
```

## Dependencies

### Internal Dependencies
- `core.base.user` - User account management

### External Dependencies
- `nixpkgs.openssh` - SSH server
- `nixpkgs.systemd` - Service management

## Extension Points

How other modules can extend this module:
- Custom notification types can be added
- Request validation can be extended
- Approval workflows can be customized

## Performance Considerations

- Request processing efficiency
- Notification delivery
- SSH config updates

## Security Considerations

- Request validation
- Password security
- Audit trail integrity
- Auto-disable functionality
- SSH config security

See [SECURITY.md](./SECURITY.md) for detailed security information.
