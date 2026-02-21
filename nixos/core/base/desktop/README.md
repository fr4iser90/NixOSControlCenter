# Desktop System

A core NixOS Control Center module that provides desktop environment configuration and management. This module supports multiple desktop environments (Plasma, GNOME, XFCE), display managers, and display servers.

## Overview

The Desktop System module is a **core module** that manages desktop environment configuration for NixOS. It supports multiple desktop environments and provides a unified interface to configure display systems, themes, and desktop features.

## Features

- **Multiple Desktop Environments**: Support for Plasma, GNOME, and XFCE
- **Display Managers**: SDDM, GDM, LightDM support
- **Display Servers**: Wayland, X11, and hybrid modes
- **Theme Management**: Dark/light theme support
- **System Integration**: Proper integration with NixOS desktop services

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices

## Related Components

- **Audio Module**: Audio system integration
- **Network Module**: Network configuration for desktop
- **User Module**: User account management
