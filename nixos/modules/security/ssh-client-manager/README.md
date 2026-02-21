# SSH Client Manager

A module that provides SSH client configuration management, connection management, and key handling for SSH clients.

## Overview

The SSH Client Manager is a **module** that manages SSH client configurations, connections, and keys. It provides tools for managing SSH connections, key management, and client-side SSH configuration.

## Quick Start

```nix
{
  modules = {
    security = {
      ssh-client-manager = {
        enable = true;
      };
    };
  };
}
```

## Features

- **Connection Management**: Manage SSH connections and configurations
- **Key Management**: SSH key handling and management
- **Configuration**: Client-side SSH configuration
- **Integration**: Works with SSH server manager

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices
- [Security](./doc/SECURITY.md) - Security considerations and threat model

## Related Components

- **SSH Server Manager**: SSH server-side management
- **User Module**: User account management
