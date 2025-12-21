# Boot System

A core NixOS Control Center module that provides bootloader management and system boot configuration. This module supports multiple bootloaders (systemd-boot, GRUB, rEFInd) and provides a unified interface for boot management.

## Overview

The Boot System module is a **core module** that manages the system bootloader and boot configuration. It dynamically loads the appropriate bootloader implementation based on the system configuration and provides common boot settings.

## Features

- **Multiple Bootloaders**: Support for systemd-boot, GRUB, and rEFInd
- **Dynamic Loading**: Automatic bootloader selection based on configuration
- **Common Settings**: Unified boot configuration (kernel, initrd, etc.)
- **Validation**: Bootloader selection validation

## Architecture

### File Structure

```
boot/
├── README.md                    # This documentation
├── CHANGELOG.md                 # Version history
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic & symlink management
├── boot-config.nix              # User configuration (symlinked)
└── bootloaders/                 # Bootloader implementations
    ├── systemd-boot.nix        # systemd-boot configuration
    ├── grub.nix                 # GRUB configuration
    └── refind.nix               # rEFInd configuration
```

### Bootloaders

#### systemd-boot (`bootloader = "systemd-boot"`)
- Modern EFI bootloader integrated with systemd
- Fast boot times and simple configuration
- EFI-only (recommended for UEFI systems)

#### GRUB (`bootloader = "grub"`)
- Traditional bootloader with wide compatibility
- Supports both legacy BIOS and UEFI
- Advanced configuration options
- Theme support and custom menus

#### rEFInd (`bootloader = "refind"`)
- Polished EFI boot manager
- Graphical interface with icons
- Automatic OS detection
- Theme support

## Configuration

The bootloader is selected centrally in `system-config.nix`:

```nix
{
  system = {
    bootloader = "systemd-boot";  # Options: "systemd-boot", "grub", "refind"
  };
}
```

The boot module itself has no additional user-configurable options - it uses the bootloader selection to dynamically load the appropriate implementation.

## Technical Details

### Dynamic Loading

The module dynamically loads bootloader implementations:

- **default.nix**: Reads `systemConfig.core.base.bootloader` and imports appropriate bootloader
- **bootloaders/**: Contains specific configurations for each bootloader
- **Validation**: Ensures only valid bootloaders are selected
- **Fallback**: Defaults to systemd-boot if invalid selection

### Common Configuration

All bootloaders receive common settings:
- **Kernel**: Latest kernel packages (`linuxPackages_latest`)
- **Initrd**: Zstd compression with high compression level
- **Modules**: Default modules included

### Bootloader-Specific Configuration

Each bootloader implementation provides:
- EFI/boot partition configuration
- Boot menu settings
- Timeout and default entry configuration
- Security settings (secure boot, etc.)

## Usage

### Changing Bootloader

1. Edit `system-config.nix`:
   ```nix
   {
     system = {
       bootloader = "grub";  # Change from systemd-boot to GRUB
     };
   }
   ```

2. Rebuild system:
   ```bash
   sudo nixos-rebuild switch
   ```

### Bootloader Maintenance

- **systemd-boot**: Uses `bootctl` for management
- **GRUB**: Uses `grub-install` and `grub-mkconfig`
- **rEFInd**: Configuration in `/boot/EFI/refind/`

## Dependencies

Bootloader-specific packages are installed automatically:
- **systemd-boot**: Included with systemd
- **GRUB**: `grub2`, `grub2-efi`
- **rEFInd**: `refind`

## Troubleshooting

### Common Issues

1. **Bootloader Not Found**: Check bootloader spelling in configuration
2. **EFI Issues**: Ensure system is booted in UEFI mode for EFI bootloaders
3. **Secure Boot**: Some bootloaders have secure boot considerations

### Bootloader Commands

```bash
# systemd-boot
bootctl status
bootctl list

# GRUB
sudo grub-install --target=x86_64-efi --efi-directory=/boot
sudo grub-mkconfig -o /boot/grub/grub.cfg

# rEFInd
# Configuration in /boot/EFI/refind/refind.conf
```

## Development

This module follows the unified MODULE_TEMPLATE architecture:

- **Provider Pattern**: Bootloaders as providers with semantic naming
- **Dynamic Loading**: Runtime bootloader selection
- **Validation**: Input validation for bootloader selection
- **Common Configuration**: Shared boot settings across all bootloaders
