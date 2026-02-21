# Hardware System

A core NixOS Control Center module that provides hardware detection and configuration. This module manages CPU, GPU, and memory configurations with automatic detection and manual override options.

## Overview

The Hardware System module is a **core module** that manages hardware-specific configurations for NixOS. It supports automatic hardware detection via system-checks and provides manual configuration options for CPU, GPU, and memory settings.

## Features

- **CPU Configuration**: Support for Intel, AMD, and VM CPUs
- **GPU Configuration**: Support for NVIDIA, AMD, Intel, and hybrid setups
- **Memory Detection**: Automatic RAM size detection via system-checks
- **Hardware Optimization**: Hardware-specific optimizations and packages
- **System Integration**: Proper integration with NixOS hardware services

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices

## Related Components

- **System Checks**: Automatic hardware detection
- **Desktop Module**: Desktop environment hardware integration
- **Boot Module**: Boot configuration for hardware
