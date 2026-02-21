# Network System

A core NixOS Control Center module that provides basic networking configuration, NetworkManager setup, and firewall management. This module handles fundamental network settings and provides infrastructure for advanced network configurations.

## Overview

The Network System module is a **core module** that establishes the foundation for networking in NixOS. It configures basic network settings, enables NetworkManager by default, and provides firewall infrastructure with intelligent service-based rules.

## Quick Start

```nix
{
  network = {
    networkManager = {
      dns = "systemd-resolved";  # DNS configuration
    };
    networking = {
      firewall = {
        trustedNetworks = [ "192.168.1.0/24" ];
      };
      services = {
        ssh = {
          exposure = "public";
          port = 22;
        };
      };
    };
  };
}
```

## Features

- **Basic Networking**: Hostname and timezone configuration
- **NetworkManager**: Wireless and wired network management
- **Firewall**: Intelligent service-based firewall rules
- **Service Integration**: Automatic firewall rules for configured services
- **Security Warnings**: Alerts for potentially unsafe service exposures

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices
- [Security](./doc/SECURITY.md) - Security considerations and threat model

## Related Components

- **Desktop Module**: Desktop environment network integration
- **System Manager**: System-level network management
