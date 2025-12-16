# Changelog

All notable changes to the Boot System module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-12-09

### Added
- Initial release of the Boot System core module
- Support for multiple bootloaders: systemd-boot, GRUB, and rEFInd
- Dynamic bootloader loading based on system configuration
- Symlink management for user configuration
- Common boot settings (kernel, initrd compression, modules)
- Bootloader selection validation

### Technical
- Implemented proper MODULE_TEMPLATE structure
- Created bootloaders/ directory for bootloader implementations
- Added symlink management for centralized config access
- Implemented validation for bootloader selection
- Added version tracking with `_version` option

### Bootloaders
- **systemd-boot**: Modern EFI bootloader with systemd integration
- **GRUB**: Traditional bootloader with BIOS/UEFI support
- **rEFInd**: Graphical EFI boot manager with automatic OS detection

### Configuration
- Dynamic loading based on `systemConfig.system.bootloader`
- User configuration via `boot-config.nix` symlink
- Validation of bootloader selection
- Default bootloader: systemd-boot

### Common Settings
- **Kernel**: Latest kernel packages (`linuxPackages_latest`)
- **Initrd**: Zstd compression with high compression ratio
- **Modules**: Default modules included for all bootloaders

### Bootloader Features
- **systemd-boot**: EFI-only, fast boot times, simple configuration
- **GRUB**: Legacy BIOS and UEFI support, themes, advanced options
- **rEFInd**: Graphical interface, automatic OS detection, themes

### Documentation
- Added comprehensive README.md with bootloader details
- Created CHANGELOG.md for version tracking
- Provider-based architecture documentation
