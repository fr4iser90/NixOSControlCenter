# Network System

A core NixOS Control Center module that provides basic networking configuration, NetworkManager setup, and firewall management. This module handles fundamental network settings and provides infrastructure for advanced network configurations.

## Overview

The Network System module is a **core module** that establishes the foundation for networking in NixOS. It configures basic network settings, enables NetworkManager by default, and provides firewall infrastructure with intelligent service-based rules.

## Features

- **Basic Networking**: Hostname and timezone configuration
- **NetworkManager**: Wireless and wired network management
- **Firewall**: Intelligent service-based firewall rules
- **Service Integration**: Automatic firewall rules for configured services
- **Security Warnings**: Alerts for potentially unsafe service exposures

## Architecture

### File Structure

```
network/
├── README.md                    # This documentation
├── CHANGELOG.md                 # Version history
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic & symlink management
├── network-config.nix           # User configuration (symlinked)
├── networkmanager.nix           # NetworkManager configuration
├── firewall.nix                 # Firewall configuration
├── lib/                         # Utility functions
│   └── rules.nix               # Firewall rule generation
└── recommendations/             # Service recommendations
    └── services.nix            # Service security recommendations
```

### Core Components

#### NetworkManager (`networkmanager.nix`)
- Wireless network management with power saving options
- MAC address randomization for privacy
- Configurable DNS settings

#### Firewall (`firewall.nix`)
- Service-based firewall rule generation
- Automatic rule creation for configured services
- Trusted network support
- Security warnings for unsafe configurations

#### Utilities (`lib/`)
- **rules.nix**: Firewall rule generation logic
- Intelligent rule creation based on service configurations

#### Recommendations (`recommendations/`)
- **services.nix**: Security recommendations for common services
- Default exposure levels (local vs public)
- Risk assessments for service configurations

## Configuration

As a core module, the network system provides essential networking functionality. Additional configuration can be done through the user config:

```nix
{
  network = {
    networkManager = {
      dns = "systemd-resolved";  # DNS configuration
    };

    networking = {
      firewall = {
        trustedNetworks = [
          "192.168.1.0/24"  # Trust local network
          "10.0.0.0/8"      # Trust VPN networks
        ];
      };

      services = {
        ssh = {
          exposure = "public";  # Allow SSH from anywhere (with warning)
          port = 22;
        };
        http = {
          exposure = "local";   # HTTP only from local network
          port = 80;
        };
      };
    };
  };
}
```

## Firewall System

### Service-Based Rules

The firewall automatically generates rules based on service configurations:

```nix
networking.services.ssh = {
  exposure = "public";  # Allow from anywhere
  port = 22;
  protocol = "tcp";
};
```

### Exposure Levels

- **local**: Only accessible from trusted networks
- **public**: Accessible from anywhere (generates security warnings)

### Automatic Rule Generation

For each configured service, the firewall:
- Opens the specified port/protocol
- Applies exposure-based filtering
- Generates iptables rules
- Provides security warnings for risky configurations

## Technical Details

### Basic Configuration

The module always configures:
- **Hostname**: Set from `systemConfig.core.base.network.hostName`
- **Timezone**: Set from `systemConfig.timeZone`
- **NetworkManager**: Enabled by default
- **Firewall**: Basic ping allowance

### NetworkManager Features

- **WiFi Power Saving**: Configurable power management
- **MAC Randomization**: Privacy protection for wireless
- **DNS Integration**: Configurable DNS resolution

### Validation

The module includes assertions for:
- Hostname must be specified
- Timezone must be specified
- Service configurations are validated

## Dependencies

- **NetworkManager**: Wireless and wired network management
- **iptables**: Firewall rule management
- **systemd**: Network service management

## Security Considerations

### Firewall Warnings

The module generates warnings for potentially unsafe configurations:
- Services exposed publicly when recommended for local access
- Missing security considerations for service exposure

### Best Practices

- Use "local" exposure for development services
- Carefully consider "public" exposure implications
- Regularly review firewall rules and service configurations

## Development

This module follows the unified MODULE_TEMPLATE architecture:

- **Service-Oriented**: Firewall rules based on service configurations
- **Security-First**: Warnings for potentially unsafe configurations
- **Modular Design**: Separate components for different network aspects
- **Validation**: Comprehensive configuration validation

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions (if available)
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices (if available)
- [Security](./doc/SECURITY.md) - Security considerations and threat model (if available)

## Related Components

- **Desktop Module**: Desktop environment network integration
- **System Manager**: System-level network management
