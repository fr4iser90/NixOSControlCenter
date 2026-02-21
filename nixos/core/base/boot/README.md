# Boot System

A core NixOS Control Center module that provides bootloader configuration and boot management. This module supports multiple bootloaders (systemd-boot, GRUB, rEFInd) and provides a unified configuration interface.

## Overview

The Boot System module is a **core module** that manages bootloader configuration for NixOS. It supports multiple bootloaders and provides a simple interface to switch between different boot systems.

## Features

- **Multiple Bootloaders**: Support for systemd-boot, GRUB, and rEFInd
- **Automatic Configuration**: Dynamic loading of appropriate bootloader configuration
- **Optimized Initrd**: Zstd compression with multi-threading
- **Latest Kernel**: Uses latest kernel packages by default
- **System Integration**: Proper integration with NixOS boot services

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices

## Related Components

- **System Manager**: System type detection
- **Hardware Module**: Hardware-specific boot configurations
- **Boot Entry Manager**: Advanced boot entry management (optional module)
