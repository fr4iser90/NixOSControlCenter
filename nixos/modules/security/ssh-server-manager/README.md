# SSH Server Manager

A comprehensive SSH server management system with request-based access control, providing secure and auditable temporary password authentication.

## Overview

The SSH Server Manager provides a complete workflow for managing SSH access requests and temporary password authentication. It replaces the old confusing system with clear, well-named commands and proper approval workflows.

## Quick Start

```nix
{
  modules = {
    security = {
      ssh-server-manager = {
        enable = true;
        notifications = {
          enable = true;
          types = {
            email = {
              enable = true;
              address = "admin@example.com";
            };
          };
        };
      };
    };
  };
}
```

## Features

- **Request-Based Access**: Users request temporary SSH access
- **Approval Workflow**: Administrators approve/deny requests
- **Temporary Passwords**: Secure temporary password authentication
- **Audit Trail**: Complete request lifecycle tracking
- **Notifications**: Email, desktop, and webhook notifications
- **Auto-Disable**: Automatic password authentication disable after timeout

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices
- [Security](./doc/SECURITY.md) - Security considerations and threat model

## Related Components

- **SSH Client Manager**: SSH client-side management
- **User Module**: User account management
