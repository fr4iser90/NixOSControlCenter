# Audio System

A core NixOS Control Center module that provides comprehensive audio system management. This module supports multiple audio systems (PipeWire, PulseAudio, ALSA) and provides a unified configuration interface.

## Overview

The Audio System module is a **core module** that manages audio services and configurations for NixOS. It supports multiple audio backends and provides a simple interface to switch between different audio systems.

## Features

- **Multiple Audio Systems**: Support for PipeWire, PulseAudio, and ALSA
- **Automatic Configuration**: Dynamic loading of appropriate audio system configuration
- **Audio Tools**: Common audio utilities and control applications
- **System Integration**: Proper integration with NixOS audio services

## Quick Start

```nix
{
  audio = {
    enable = true;           # Enable audio system (default: true)
    system = "pipewire";     # Audio system: "pipewire", "pulseaudio", "alsa", "none"
  };
}
```

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices

## Related Components

- **Desktop Module**: Desktop environment audio integration
- **User Module**: User-specific audio preferences
