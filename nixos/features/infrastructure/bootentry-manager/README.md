# Boot Entry Manager

A feature module that provides advanced bootloader entry management for systemd-boot, GRUB, and rEFInd. This module allows dynamic management of boot entries, custom naming, and synchronization across different bootloader implementations.

## Overview

The Boot Entry Manager is a **feature module** that provides unified boot entry management across different bootloaders. It supports creating, renaming, and managing boot entries with a consistent interface regardless of the underlying bootloader.

## Features

- **Multi-Bootloader Support**: Works with systemd-boot, GRUB, and rEFInd
- **Dynamic Entry Management**: Create, rename, and remove boot entries
- **Entry Synchronization**: Keeps entries synchronized across bootloader formats
- **JSON-Based Storage**: Human-readable entry definitions
- **Activation Scripts**: Automatic bootloader entry updates on system activation

## Architecture

### File Structure

```
bootentry/
├── README.md                    # This documentation
├── CHANGELOG.md                 # Version history
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic & symlink management
├── bootentry-config.nix         # User configuration (symlinked)
├── lib/                         # Shared utility functions
│   ├── common.nix              # Common utilities
│   └── types.nix               # Type definitions
└── providers/                   # Bootloader-specific implementations
    ├── systemd-boot.nix        # systemd-boot provider
    ├── grub.nix                # GRUB provider
    └── refind.nix              # rEFInd provider
```

### Providers

#### systemd-boot Provider
- **Storage**: JSON files in `/etc/nixos/boot/entries/`
- **Bootloader Integration**: Direct EFI entry management
- **Features**: Entry ordering, custom titles, parameters

#### GRUB Provider
- **Storage**: GRUB configuration integration
- **Bootloader Integration**: Menu entry management
- **Features**: Submenu support, custom kernels

#### rEFInd Provider
- **Storage**: rEFInd configuration files
- **Bootloader Integration**: Manual configuration updates
- **Features**: Icon support, theme integration

## Configuration

Enable the boot entry manager in your configuration:

```nix
{
  features = {
    infrastructure = {
      bootentry = {
        enable = true;
      };
    };
  };
}
```

## Boot Entry Management

### Creating Entries

Boot entries are managed through JSON files in `/etc/nixos/boot/entries/`:

```json
{
  "title": "NixOS",
  "kernel": "/boot/EFI/nixos/kernel.efi",
  "initrd": "/boot/EFI/nixos/initrd.efi",
  "cmdline": "root=UUID=... quiet splash",
  "order": 1
}
```

### Management Commands

The module provides command-line tools:

- **`ncc bootentry list`**: List all boot entries
- **`ncc bootentry rename <old> <new>`**: Rename a boot entry
- **`ncc bootentry reset <name>`**: Reset entry to default

### Entry Synchronization

- **Automatic Sync**: Entries are synchronized during system activation
- **Provider-Specific**: Each provider handles entry creation appropriately
- **Backup Support**: Previous configurations are backed up

## Technical Details

### JSON Storage Format

Boot entries use a standardized JSON format:

```json
{
  "title": "Entry Title",
  "kernel": "/path/to/kernel",
  "initrd": "/path/to/initrd",
  "cmdline": "kernel parameters",
  "order": 1,
  "provider": "systemd-boot"
}
```

### Activation Process

1. **Entry Discovery**: Scans `/etc/nixos/boot/entries/` for JSON files
2. **Validation**: Validates entry format and required fields
3. **Provider Dispatch**: Routes entries to appropriate bootloader provider
4. **Entry Creation**: Creates bootloader-specific entries
5. **Cleanup**: Removes orphaned entries

### Provider Architecture

Each provider implements a common interface:

- **activation.initializeJson**: Initialize entry storage
- **activation.syncEntries**: Synchronize entries to bootloader
- **scripts.listEntries**: List current entries
- **scripts.renameEntry**: Rename entries
- **scripts.resetEntry**: Reset entries

## Bootloader Compatibility

### systemd-boot
- **Entry Type**: EFI boot entries
- **Storage**: EFI variables
- **Features**: Native JSON support, ordering
- **Limitations**: EFI-only systems

### GRUB
- **Entry Type**: GRUB menu entries
- **Storage**: GRUB configuration files
- **Features**: Legacy BIOS support, submenus
- **Limitations**: Configuration file editing

### rEFInd
- **Entry Type**: rEFInd manual configuration
- **Storage**: rEFInd config files
- **Features**: Graphical interface, icons
- **Limitations**: Manual configuration updates

## Usage Examples

### Basic Setup

```nix
# Enable boot entry management
features.infrastructure.bootentry.enable = true;

# Create a custom boot entry
# Place JSON file in /etc/nixos/boot/entries/custom.json
{
  "title": "Custom NixOS",
  "kernel": "/boot/EFI/nixos/kernel.efi",
  "initrd": "/boot/EFI/nixos/initrd.efi",
  "cmdline": "root=/dev/sda1 quiet splash custom_option=1"
}
```

### Multi-Boot Setup

```nix
# Enable for multi-boot environment
features.infrastructure.bootentry.enable = true;

# Entries for different OSes
# /etc/nixos/boot/entries/nixos.json
# /etc/nixos/boot/entries/windows.json
# /etc/nixos/boot/entries/ubuntu.json
```

### Custom Kernels

```json
{
  "title": "Custom Kernel",
  "kernel": "/boot/custom-kernel",
  "initrd": "/boot/custom-initrd",
  "cmdline": "root=UUID=... custom.kernel.option=1",
  "order": 2
}
```

## Integration

### System Boot Process

- **Early Activation**: Runs during `system.activationScripts`
- **Bootloader Update**: Updates bootloader configuration before reboot
- **Entry Persistence**: Entries survive system updates

### Command Center Integration

Provides commands through the command center:
- Boot entry listing and management
- Integration with other system management tools

## Development

This module follows the unified MODULE_TEMPLATE architecture:

- **Provider Pattern**: Bootloader-specific implementations
- **JSON Configuration**: Human-readable entry definitions
- **Activation-Based**: Updates during system activation
- **Cross-Platform**: Works across different bootloader types

## Troubleshooting

### Common Issues

1. **Entries Not Appearing**: Check JSON syntax and required fields
2. **Bootloader Conflicts**: Ensure only one bootloader provider is active
3. **Permission Issues**: Check file permissions in `/etc/nixos/boot/`

### Debug Commands

```bash
# Check JSON syntax
jq . /etc/nixos/boot/entries/*.json

# View bootloader entries
efibootmgr  # For systemd-boot
grep -A 10 "menuentry" /boot/grub/grub.cfg  # For GRUB

# Check activation logs
journalctl -u nixos-activation
```

## Security Considerations

### Boot Entry Security

- **Trusted Sources**: Only load entries from trusted locations
- **Validation**: Validate kernel and initrd paths
- **Access Control**: Restrict boot entry modification

### EFI Security

- **Secure Boot**: Compatible with secure boot environments
- **Signature Verification**: Supports signed bootloaders
- **EFI Variables**: Proper EFI variable management
