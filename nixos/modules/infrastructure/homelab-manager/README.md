# Homelab Manager

A module for managing homelab environments using Docker containers, with support for both single-server and Docker Swarm modes.

## Overview

The Homelab Manager is a **module** that provides comprehensive homelab environment management. It supports Docker Compose stack management, Docker Swarm mode, and user-based Docker access control.

## Quick Start

```nix
{
  enable = true;
  stacks = [
      {
        name = "my-stack";
        compose = "/path/to/docker-compose.yml";
        env = "/path/to/.env";
        }
    ];
}
```

## Features

- **Environment Creation**: Create and configure homelab environments
- **Docker Compose**: Stack management with Docker Compose
- **Swarm Mode**: Support for Docker Swarm multi-node setups
- **User-Based Access**: Docker access control based on user roles
- **Integrated Commands**: Command-center integration for management

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices

## Related Components

- **Packages Module**: Docker package management
- **User Module**: User role management for Docker access
