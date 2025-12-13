# Changelog

All notable changes to the Boot Entry Manager feature module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-12-09

### Added
- Initial release of the Boot Entry Manager feature module
- Multi-bootloader support for systemd-boot, GRUB, and rEFInd
- JSON-based boot entry configuration and storage
- Dynamic boot entry management with create, rename, and reset functionality
- Automatic entry synchronization across bootloader providers
- Symlink management for user configuration
- Activation script integration for seamless boot entry updates

### Technical
- Implemented proper MODULE_TEMPLATE structure
- Created provider-based architecture for different bootloaders
- Added symlink management for centralized config access
- Implemented JSON configuration format for boot entries
- Added version tracking with `_version` option

### Bootloader Providers
- **systemd-boot**: EFI boot entry management with ordering support
- **GRUB**: Menu entry configuration with submenu capabilities
- **rEFInd**: Manual configuration file management with icon support

### Boot Entry Management
- **JSON Storage**: Human-readable entry definitions in `/etc/nixos/boot/entries/`
- **Entry Validation**: Required field checking and format validation
- **Provider Dispatch**: Automatic routing to appropriate bootloader implementation
- **Activation Integration**: Updates during system activation scripts

### Configuration Features
- **Standard Fields**: title, kernel, initrd, cmdline, order
- **Provider-Specific**: Bootloader-dependent configuration options
- **Entry Ordering**: Configurable boot entry priority
- **Custom Parameters**: Flexible kernel command line options

### Management Tools
- **List Entries**: Display all configured boot entries
- **Rename Entries**: Change boot entry titles
- **Reset Entries**: Restore entries to default configuration
- **Sync Mechanism**: Automatic synchronization across providers

### Security Features
- **Path Validation**: Kernel and initrd path verification
- **Access Control**: Restricted boot entry modification
- **EFI Integration**: Secure boot compatibility
- **File Permissions**: Proper permission management for boot files

### Documentation
- Added comprehensive README.md with bootloader-specific details
- Created CHANGELOG.md for version tracking
- Included configuration examples and troubleshooting guides

### Architecture
- **Provider Pattern**: Modular bootloader implementations
- **JSON Configuration**: Standardized entry format across providers
- **Activation-Based**: Updates integrated into system activation
- **Cross-Bootloader**: Unified interface for different bootloader types
