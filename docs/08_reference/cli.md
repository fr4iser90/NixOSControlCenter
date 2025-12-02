# CLI Reference

## Overview

The NixOSControlCenter CLI provides a comprehensive command-line interface for managing all aspects of your NixOS system. All commands follow a consistent pattern and provide detailed help information.

## Command Structure

```bash
nixos-control-center <category> <command> [options] [arguments]
```

### Categories
- `system` - System management and status
- `package` - Package management
- `user` - User management
- `network` - Network configuration
- `hardware` - Hardware detection and configuration
- `desktop` - Desktop environment management
- `container` - Container management
- `vm` - Virtual machine management
- `ssh` - SSH client and server management
- `ai` - AI workspace management
- `homelab` - Homelab automation
- `config` - Configuration management
- `update` - System updates
- `backup` - Backup and restore operations

## System Commands

### System Status
```bash
# Show overall system status
nixos-control-center status

# Show detailed system information
nixos-control-center info

# Show version information
nixos-control-center version

# Perform system health check
nixos-control-center health

# Show system resources
nixos-control-center system resources

# Monitor system usage
nixos-control-center system monitor
```

### System Management
```bash
# Optimize system performance
nixos-control-center system optimize

# Clean up temporary files
nixos-control-center cleanup

# Restart system services
nixos-control-center system restart

# Shutdown system
nixos-control-center system shutdown

# Reboot system
nixos-control-center system reboot
```

### System Logs
```bash
# View system logs
nixos-control-center logs

# View specific log file
nixos-control-center logs <log-file>

# Follow log output
nixos-control-center logs --follow

# Filter logs by level
nixos-control-center logs --level error
```

## Package Commands

### Package Management
```bash
# Search for packages
nixos-control-center package search <query>

# Install package
nixos-control-center package install <package-name>

# Remove package
nixos-control-center package remove <package-name>

# List installed packages
nixos-control-center package list

# Update package
nixos-control-center package update <package-name>

# Show package information
nixos-control-center package info <package-name>
```

### Package Cache
```bash
# Clear package cache
nixos-control-center package cache clear

# Show cache statistics
nixos-control-center package cache stats

# Clean unused packages
nixos-control-center package cache clean
```

## User Commands

### User Management
```bash
# Add new user
nixos-control-center user add <username>

# Remove user
nixos-control-center user remove <username>

# List all users
nixos-control-center user list

# Show user information
nixos-control-center user info <username>

# Configure user
nixos-control-center user configure <username>
```

### User Roles
```bash
# Set user role
nixos-control-center user role <username> <role>

# List available roles
nixos-control-center user roles

# Show user permissions
nixos-control-center user permissions <username>
```

### Password Management
```bash
# Set user password
nixos-control-center user password <username>

# Generate secure password
nixos-control-center user password generate

# Check password strength
nixos-control-center user password check <password>
```

## Network Commands

### Network Status
```bash
# Show network status
nixos-control-center network status

# List network interfaces
nixos-control-center network interfaces

# Test network connectivity
nixos-control-center network test

# Show network configuration
nixos-control-center network config
```

### Network Configuration
```bash
# Configure network interface
nixos-control-center network configure <interface>

# Connect to WiFi
nixos-control-center network wifi connect <ssid>

# Disconnect from WiFi
nixos-control-center network wifi disconnect

# Show WiFi networks
nixos-control-center network wifi scan
```

### Firewall Management
```bash
# Show firewall status
nixos-control-center network firewall status

# Configure firewall
nixos-control-center network firewall configure

# Add firewall rule
nixos-control-center network firewall add <rule>

# Remove firewall rule
nixos-control-center network firewall remove <rule>
```

## Hardware Commands

### Hardware Detection
```bash
# Show hardware information
nixos-control-center hardware info

# Detect hardware
nixos-control-center hardware detect

# Show GPU information
nixos-control-center hardware gpu

# Show CPU information
nixos-control-center hardware cpu

# Show memory information
nixos-control-center hardware memory
```

### Hardware Configuration
```bash
# Configure hardware
nixos-control-center hardware configure

# Configure GPU
nixos-control-center hardware gpu configure

# Configure CPU
nixos-control-center hardware cpu configure

# Configure memory
nixos-control-center hardware memory configure
```

## Desktop Commands

### Desktop Environment
```bash
# Set up desktop environment
nixos-control-center desktop setup <environment>

# Apply desktop changes
nixos-control-center desktop apply

# Show desktop status
nixos-control-center desktop status

# Configure desktop
nixos-control-center desktop configure
```

### Theme Management
```bash
# List available themes
nixos-control-center theme list

# Apply theme
nixos-control-center theme apply <theme-name>

# Customize colors
nixos-control-center theme colors <scheme>

# Configure fonts
nixos-control-center theme fonts <font-family>
```

## Container Commands

### Container Management
```bash
# List containers
nixos-control-center container list

# Start container
nixos-control-center container start <name>

# Stop container
nixos-control-center container stop <name>

# Restart container
nixos-control-center container restart <name>

# Remove container
nixos-control-center container remove <name>
```

### Container Information
```bash
# Show container information
nixos-control-center container info <name>

# Show container logs
nixos-control-center container logs <name>

# Show container stats
nixos-control-center container stats <name>

# Execute command in container
nixos-control-center container exec <name> <command>
```

## VM Commands

### VM Management
```bash
# List virtual machines
nixos-control-center vm list

# Create virtual machine
nixos-control-center vm create <name>

# Start virtual machine
nixos-control-center vm start <name>

# Stop virtual machine
nixos-control-center vm stop <name>

# Remove virtual machine
nixos-control-center vm remove <name>
```

### VM Configuration
```bash
# Configure virtual machine
nixos-control-center vm configure <name>

# Show VM information
nixos-control-center vm info <name>

# Show VM status
nixos-control-center vm status <name>

# Connect to VM console
nixos-control-center vm console <name>
```

## SSH Commands

### SSH Client
```bash
# Generate SSH key
nixos-control-center ssh key generate

# Add SSH key to server
nixos-control-center ssh key add <server>

# Test SSH connection
nixos-control-center ssh test <server>

# Connect to server
nixos-control-center ssh connect <server>
```

### SSH Server
```bash
# Configure SSH server
nixos-control-center ssh server configure

# Start SSH server
nixos-control-center ssh server start

# Stop SSH server
nixos-control-center ssh server stop

# Show SSH server status
nixos-control-center ssh server status
```

## AI Workspace Commands

### AI Workspace Management
```bash
# Initialize AI workspace
nixos-control-center ai workspace init

# Show AI workspace status
nixos-control-center ai workspace status

# Start AI services
nixos-control-center ai services start

# Stop AI services
nixos-control-center ai services stop

# Restart AI services
nixos-control-center ai services restart
```

### AI Models
```bash
# List AI models
nixos-control-center ai models list

# Download AI model
nixos-control-center ai models download <model>

# Remove AI model
nixos-control-center ai models remove <model>

# Show model information
nixos-control-center ai models info <model>
```

## Homelab Commands

### Homelab Management
```bash
# Initialize homelab
nixos-control-center homelab init

# Show homelab status
nixos-control-center homelab status

# Start homelab services
nixos-control-center homelab start

# Stop homelab services
nixos-control-center homelab stop

# Restart homelab services
nixos-control-center homelab restart
```

### Homelab Services
```bash
# List homelab services
nixos-control-center homelab services list

# Start specific service
nixos-control-center homelab services start <service>

# Stop specific service
nixos-control-center homelab services stop <service>

# Show service status
nixos-control-center homelab services status <service>
```

## Configuration Commands

### Configuration Management
```bash
# Show current configuration
nixos-control-center config show

# Edit configuration
nixos-control-center config edit

# Validate configuration
nixos-control-center config validate

# Apply configuration
nixos-control-center config apply
```

### Configuration Backup
```bash
# Backup configuration
nixos-control-center config backup

# Restore configuration
nixos-control-center config restore <backup>

# List backups
nixos-control-center config backups

# Show configuration differences
nixos-control-center config diff
```

## Update Commands

### System Updates
```bash
# Check for updates
nixos-control-center update check

# Update system
nixos-control-center update

# Update specific component
nixos-control-center update <component>

# Show update history
nixos-control-center update history
```

### Flake Management
```bash
# Update flake inputs
nixos-control-center update flake

# Lock flake inputs
nixos-control-center update lock

# Show flake status
nixos-control-center update flake status
```

## Backup Commands

### Backup Operations
```bash
# Create backup
nixos-control-center backup create

# List backups
nixos-control-center backup list

# Show backup information
nixos-control-center backup info <backup>

# Remove backup
nixos-control-center backup remove <backup>
```

### Restore Operations
```bash
# Restore from backup
nixos-control-center restore <backup>

# Preview restore
nixos-control-center restore preview <backup>

# Validate backup
nixos-control-center restore validate <backup>
```

## Global Options

All commands support these global options:

```bash
--help, -h          Show help information
--version, -v       Show version information
--verbose, -V       Enable verbose output
--quiet, -q         Suppress output
--json              Output in JSON format
--yaml              Output in YAML format
--config <file>     Use custom configuration file
--log-level <level> Set log level (debug, info, warn, error)
```

## Examples

### Basic System Management
```bash
# Check system status
nixos-control-center status

# Update system
nixos-control-center update

# Install a package
nixos-control-center package install firefox

# Add a new user
nixos-control-center user add john
```

### Advanced Operations
```bash
# Configure desktop environment
nixos-control-center desktop setup gnome

# Set up AI workspace
nixos-control-center ai workspace init

# Create homelab
nixos-control-center homelab init

# Backup configuration
nixos-control-center backup create
```

### Troubleshooting
```bash
# Check system health
nixos-control-center health

# View system logs
nixos-control-center logs

# Test network connectivity
nixos-control-center network test

# Validate configuration
nixos-control-center config validate
```

## Getting Help

### Command Help
```bash
# General help
nixos-control-center --help

# Category help
nixos-control-center <category> --help

# Command help
nixos-control-center <category> <command> --help
```

### Interactive Help
```bash
# Start interactive mode
nixos-control-center interactive

# Show available commands
nixos-control-center interactive commands

# Get command suggestions
nixos-control-center interactive suggest <query>
```

## Error Handling

### Common Error Codes
- `1`: General error
- `2`: Invalid command or option
- `3`: Permission denied
- `4`: Configuration error
- `5`: Network error
- `6`: Hardware error
- `7`: Package error

### Error Recovery
```bash
# Show error details
nixos-control-center error show <error-id>

# Retry failed operation
nixos-control-center retry <command>

# Rollback changes
nixos-control-center rollback
```

## Scripting and Automation

### Command Chaining
```bash
# Chain multiple commands
nixos-control-center update && nixos-control-center deploy

# Conditional execution
nixos-control-center health && nixos-control-center backup create
```

### Output Formats
```bash
# JSON output for scripting
nixos-control-center status --json

# YAML output for configuration
nixos-control-center config show --yaml

# Quiet mode for automation
nixos-control-center update --quiet
```

This CLI reference provides comprehensive coverage of all available commands. For more detailed information about specific commands, use the built-in help system.
