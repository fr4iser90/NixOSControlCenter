# Boot Entry Manager

A module that provides advanced bootloader entry management for systemd-boot, GRUB, and rEFInd. This module allows dynamic management of boot entries, custom naming, and synchronization across different bootloader implementations.

## Overview

The Boot Entry Manager is a **module** that provides unified boot entry management across different bootloaders. It supports creating, renaming, and managing boot entries with a consistent interface regardless of the underlying bootloader.

## Quick Start

```nix
{
  modules = {
    infrastructure = {
      bootentry-manager = {
        enable = true;
      };
    };
  };
}
```

## Features

- **Multi-Bootloader Support**: Works with systemd-boot, GRUB, and rEFInd
- **Dynamic Entry Management**: Create, rename, and remove boot entries
- **Entry Synchronization**: Keeps entries synchronized across bootloader formats
- **JSON-Based Storage**: Human-readable entry definitions
- **Activation Scripts**: Automatic bootloader entry updates on system activation

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices

## Related Components

- **Boot Module**: Bootloader configuration
- **System Manager**: System-level management
