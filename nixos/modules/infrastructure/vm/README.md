# VM Manager

A module that provides virtual machine management capabilities for NixOS, including VM creation, configuration, and lifecycle management.

## Overview

The VM Manager is a **module** that provides comprehensive virtual machine management. It supports VM creation, configuration, storage management, and integration with various virtualization technologies.

## Quick Start

```nix
{
  modules = {
    infrastructure = {
      vm = {
        enable = true;
        storage = {
          enable = true;
        };
      };
    };
  };
}
```

## Features

- **VM Creation**: Create and configure virtual machines
- **Storage Management**: VM storage configuration and management
- **Lifecycle Management**: VM start, stop, and management
- **Multiple Formats**: Support for various VM formats
- **Integration**: Works with QEMU/KVM and other virtualization technologies

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices

## Related Components

- **Hardware Module**: Hardware configuration for VMs
- **Packages Module**: Virtualization package management
