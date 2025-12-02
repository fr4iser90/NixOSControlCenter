# Quick Start Guide

## Overview

This guide will get you up and running with NixOSControlCenter in under 5 minutes. You'll learn the basic commands and workflows to manage your NixOS system effectively.

## Prerequisites

- NixOSControlCenter installed (see [Installation Guide](./installation.md))
- Basic familiarity with command line
- sudo privileges

## First Steps

### 1. Check System Status

Start by verifying your installation:

```bash
# Check overall system status
nixos-control-center status

# View hardware information
nixos-control-center hardware info

# Check network status
nixos-control-center network status
```

### 2. Basic System Management

#### Update Your System
```bash
# Update flake inputs
nixos-control-center update

# Apply updates
nixos-control-center deploy

# Check for available updates
nixos-control-center update check
```

#### Manage Packages
```bash
# Search for packages
nixos-control-center package search <package-name>

# Install a package
nixos-control-center package install <package-name>

# Remove a package
nixos-control-center package remove <package-name>

# List installed packages
nixos-control-center package list
```

### 3. User Management

#### Configure Users
```bash
# Add a new user
nixos-control-center user add <username>

# Configure user roles
nixos-control-center user role <username> admin

# List all users
nixos-control-center user list

# Remove a user
nixos-control-center user remove <username>
```

#### Manage Passwords
```bash
# Set user password
nixos-control-center user password <username>

# Generate secure password
nixos-control-center user password generate

# Check password strength
nixos-control-center user password check
```

## Common Workflows

### Desktop Setup

#### Configure Desktop Environment
```bash
# Set up GNOME desktop
nixos-control-center desktop setup gnome

# Configure Plasma desktop
nixos-control-center desktop setup plasma

# Set up XFCE desktop
nixos-control-center desktop setup xfce

# Apply desktop changes
nixos-control-center desktop apply
```

#### Manage Themes and Appearance
```bash
# List available themes
nixos-control-center theme list

# Apply a theme
nixos-control-center theme apply <theme-name>

# Customize colors
nixos-control-center theme colors <scheme>

# Configure fonts
nixos-control-center theme fonts <font-family>
```

### Network Management

#### Configure Network
```bash
# Show network interfaces
nixos-control-center network interfaces

# Configure WiFi
nixos-control-center network wifi connect <ssid>

# Set up firewall rules
nixos-control-center network firewall configure

# Test connectivity
nixos-control-center network test
```

#### SSH Management
```bash
# Generate SSH key
nixos-control-center ssh key generate

# Add SSH key to server
nixos-control-center ssh key add <server>

# Test SSH connection
nixos-control-center ssh test <server>

# Configure SSH server
nixos-control-center ssh server configure
```

### Homelab Features

#### Container Management
```bash
# List containers
nixos-control-center container list

# Start a container
nixos-control-center container start <name>

# Stop a container
nixos-control-center container stop <name>

# View container logs
nixos-control-center container logs <name>
```

#### AI Workspace
```bash
# Initialize AI workspace
nixos-control-center ai workspace init

# Start AI services
nixos-control-center ai services start

# Check AI workspace status
nixos-control-center ai workspace status

# Access AI models
nixos-control-center ai models list
```

## Quick Commands Reference

### System Information
```bash
nixos-control-center status          # Overall system status
nixos-control-center info            # Detailed system information
nixos-control-center version         # Version information
nixos-control-center health          # System health check
```

### Configuration Management
```bash
nixos-control-center config show     # Show current configuration
nixos-control-center config backup   # Backup configuration
nixos-control-center config restore  # Restore configuration
nixos-control-center config diff     # Show configuration changes
```

### Maintenance
```bash
nixos-control-center cleanup         # Clean up temporary files
nixos-control-center backup          # Create system backup
nixos-control-center restore         # Restore from backup
nixos-control-center logs            # View system logs
```

## Troubleshooting Quick Fixes

### Common Issues

#### System Won't Boot
```bash
# Boot into previous generation
# Select from boot menu, then:
nixos-control-center rollback
```

#### Package Installation Fails
```bash
# Clear package cache
nixos-control-center package cache clear

# Update flake inputs
nixos-control-center update

# Retry installation
nixos-control-center package install <package-name>
```

#### Network Issues
```bash
# Restart network services
nixos-control-center network restart

# Reset network configuration
nixos-control-center network reset

# Check firewall status
nixos-control-center network firewall status
```

#### Performance Issues
```bash
# Check system resources
nixos-control-center system resources

# Optimize performance
nixos-control-center system optimize

# Monitor system usage
nixos-control-center system monitor
```

## Next Steps

Now that you're familiar with the basics:

1. **Explore Advanced Features**: Check [Features Overview](../03_features/overview.md)
2. **Learn CLI Commands**: Review [CLI Reference](../08_reference/cli.md)
3. **Customize Configuration**: See [Configuration Guide](../08_reference/config.md)
4. **Set Up Development**: Follow [Development Setup](../05_development/setup.md)

## Getting Help

- **Command Help**: `nixos-control-center --help`
- **Specific Help**: `nixos-control-center <command> --help`
- **Documentation**: Check the [Reference Section](../08_reference/)
- **Issues**: Report on [GitHub](https://github.com/fr4iser90/NixOSControlCenter/issues)

## Tips for Success

1. **Always backup before major changes**: `nixos-control-center backup`
2. **Test configurations**: Use `nixos-control-center config test` before applying
3. **Keep system updated**: Regular updates ensure security and stability
4. **Monitor system health**: Use `nixos-control-center health` regularly
5. **Use rollback feature**: If something goes wrong, rollback is your friend

Remember: NixOSControlCenter is designed to make NixOS management easy and reliable. When in doubt, check the help system or documentation!
