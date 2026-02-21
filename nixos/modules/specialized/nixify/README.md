# Nixify

A module that extracts system state from Windows/macOS/Linux and generates declarative NixOS configurations.

> **Important:** The module runs on NixOS. The snapshot scripts run on target systems (Windows/macOS/Linux).

## Overview

**Nixify** extracts system state from Windows/macOS/Linux and generates declarative NixOS configurations from it.

## Features

- **Cross-Platform Scanning**: Windows, macOS, and Linux support
- **System State Extraction**: Captures installed packages, configurations, and more
- **NixOS Config Generation**: Generates declarative NixOS configurations
- **Web Service**: HTTP API for snapshot upload and management
- **ISO Builder**: Creates bootable NixOS ISOs

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices

## Related Components

- **System Manager**: System-level management
- **Lock Manager**: System discovery and documentation
