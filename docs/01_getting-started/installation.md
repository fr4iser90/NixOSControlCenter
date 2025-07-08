# Installation Guide

## Overview

NixOSControlCenter is a comprehensive system management tool for NixOS that provides quick setup for desktop, server, and homelab configurations. This guide will walk you through the installation process step by step.

## Prerequisites

### System Requirements
- **Operating System**: NixOS (tested on 24.11)
- **Bootloader**: systemd-boot (required)
- **RAM**: Minimum 4GB, recommended 8GB+
- **Storage**: Minimum 20GB free space
- **Network**: Internet connection for package downloads

### Hardware Compatibility
- **GPU Support**:
  - ✅ AMD GPU (Radeon series)
  - ✅ Intel GPU (integrated and discrete)
  - ✅ NVIDIA-Intel hybrid setups
  - ❌ NVIDIA-only setups (not yet supported)
- **CPU**: x86_64 architecture
- **Storage**: SSD recommended for optimal performance

### Software Dependencies
- Git (for cloning the repository)
- sudo privileges (for system configuration)
- Nix package manager (included with NixOS)

## Installation Methods

### Method 1: Quick Install (Recommended)

1. **Clone the Repository**
   ```bash
   git clone https://github.com/fr4iser90/NixOSControlCenter
   cd NixOSControlCenter
   ```

2. **Start Installation Environment**
   ```bash
   sudo nix-shell
   ```

3. **Follow Interactive Setup**
   The installer will automatically:
   - Check hardware compatibility
   - Verify system requirements
   - Configure basic system settings
   - Set up user accounts
   - Install required packages

### Method 2: Manual Installation

1. **Clone and Navigate**
   ```bash
   git clone https://github.com/fr4iser90/NixOSControlCenter
   cd NixOSControlCenter
   ```

2. **Run System Checks**
   ```bash
   ./shell/scripts/checks/hardware/hardware-config.sh
   ./shell/scripts/checks/system/bootloader.sh
   ```

3. **Choose Installation Mode**
   ```bash
   ./shell/scripts/setup/modes/desktop/setup.sh    # For desktop
   ./shell/scripts/setup/modes/server/setup.sh     # For server
   ./shell/scripts/setup/modes/homelab/setup.sh    # For homelab
   ```

## Installation Modes

### Desktop Mode
- **Purpose**: Personal desktop environment setup
- **Features**: GUI applications, development tools, multimedia
- **Time**: ~3-5 minutes
- **Storage**: ~5GB additional space

### Server Mode
- **Purpose**: Server environment with database and container support
- **Features**: Docker, databases, web services
- **Time**: ~5-7 minutes
- **Storage**: ~8GB additional space

### Homelab Mode
- **Purpose**: Complete homelab automation
- **Features**: AI workspace, containers, monitoring, automation
- **Time**: ~7-10 minutes
- **Storage**: ~15GB additional space

## Configuration Options

### User Management
- **Admin User**: Full system access
- **Guest User**: Limited access for visitors
- **Restricted Admin**: Admin with specific limitations

### Network Configuration
- **Firewall**: Automatic configuration based on mode
- **SSH**: Secure remote access setup
- **VPN**: Optional VPN configuration

### Storage Configuration
- **Encryption**: Optional disk encryption
- **Backup**: Automatic backup configuration
- **Monitoring**: Storage monitoring setup

## Post-Installation Steps

### 1. Verify Installation
```bash
# Check system status
nixos-control-center status

# Verify hardware detection
nixos-control-center hardware info

# Test network connectivity
nixos-control-center network test
```

### 2. Configure User Preferences
```bash
# Set up user profile
nixos-control-center user configure

# Configure desktop environment
nixos-control-center desktop setup
```

### 3. Update System
```bash
# Update flake inputs
nixos-control-center update

# Apply updates
nixos-control-center deploy
```

## Troubleshooting

### Common Issues

#### Installation Fails
**Problem**: Installation script fails with errors
**Solution**:
```bash
# Check logs
tail -f /var/log/nixos-control-center/install.log

# Verify system requirements
./shell/scripts/checks/hardware/hardware-config.sh

# Try manual installation
./shell/scripts/setup/config/system-config.template.nix
```

#### Hardware Not Detected
**Problem**: GPU or other hardware not recognized
**Solution**:
```bash
# Check hardware compatibility
lspci | grep -i vga

# Update hardware configuration
nixos-control-center hardware configure

# Reboot and retry
sudo reboot
```

#### Network Issues
**Problem**: Network connectivity problems during installation
**Solution**:
```bash
# Check network status
systemctl status NetworkManager

# Configure network manually
nixos-control-center network configure

# Test connectivity
ping -c 3 8.8.8.8
```

#### Boot Issues
**Problem**: System won't boot after installation
**Solution**:
```bash
# Boot into recovery mode
# Select previous generation from boot menu

# Rollback configuration
nixos-control-center rollback

# Check bootloader configuration
nixos-control-center boot status
```

### Log Files
- **Installation Log**: `/var/log/nixos-control-center/install.log`
- **System Log**: `/var/log/nixos-control-center/system.log`
- **Error Log**: `/var/log/nixos-control-center/error.log`

### Getting Help
- **Documentation**: Check [Troubleshooting Guide](../08_reference/troubleshooting.md)
- **Issues**: Report on [GitHub Issues](https://github.com/fr4iser90/NixOSControlCenter/issues)
- **Community**: Join NixOS community forums

## Next Steps

After successful installation:

1. **Read the [Quick Start Guide](./quick-start.md)** for basic usage
2. **Explore [Features Overview](../03_features/overview.md)** to understand capabilities
3. **Check [CLI Reference](../08_reference/cli.md)** for command usage
4. **Review [Configuration Guide](../08_reference/config.md)** for customization

## Uninstallation

To remove NixOSControlCenter:

```bash
# Remove configuration
sudo rm -rf /etc/nixos/control-center

# Remove packages
nixos-control-center uninstall

# Clean up user data
rm -rf ~/.config/nixos-control-center
```

**Note**: This will remove all NixOSControlCenter configurations but preserve your base NixOS system.
