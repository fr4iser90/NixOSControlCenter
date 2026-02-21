# Packages System

A core NixOS Control Center module that provides comprehensive package management with feature-based organization, intelligent dependency resolution, and preset configurations.

## Overview

The Packages System module is a **core module** that manages system-wide and user-specific packages for NixOS. It provides a feature-based package organization system with automatic dependency resolution, preset configurations, and intelligent Docker mode selection.

## Features

- **Feature-Based Packages**: Organized by features (gaming, development, virtualization)
- **Intelligent Dependencies**: Automatic dependency resolution and conflict detection
- **Preset Configurations**: Pre-configured package sets for common use cases
- **Docker Intelligence**: Automatic Docker mode selection (rootless vs root)
- **System/User Packages**: Separate system-wide and user-specific package management
- **Legacy Support**: Backward compatibility with old packageModules structure

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices

## Related Components

- **System Manager**: System type detection
- **Home Manager**: User-specific package management
- **Docker Modules**: Docker configuration integration
