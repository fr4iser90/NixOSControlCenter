# Changelog

All notable changes to the Packages System module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-12-09

### Added
- Initial release of the Packages System core module
- Feature-based package management with intelligent dependency resolution
- Preset support for common use cases (gaming-desktop, dev-workstation, homelab-server)
- Automatic Docker mode selection (rootless vs root based on system configuration)
- Comprehensive metadata system with feature definitions, dependencies, and conflicts
- Legacy migration support for old packageModules structure
- System type filtering (desktop vs server features)
- Symlink management for user configuration

### Technical
- Implemented proper MODULE_TEMPLATE structure
- Created modular architecture with base packages, features, and presets
- Added symlink management for centralized config access
- Implemented comprehensive dependency resolution and conflict detection
- Added version tracking with `_version` option

### Feature System
- **Gaming Features**: gaming, streaming, emulation packages
- **Development Features**: web-dev, python-dev, system-dev, game-dev packages
- **Virtualization Features**: docker, docker-rootless, podman, qemu-vm, virt-manager
- **Server Features**: database, web-server, mail-server packages

### Preset Configurations
- **gaming-desktop**: Complete gaming environment with launchers and tools
- **dev-workstation**: Full development environment with multiple language support
- **homelab-server**: Home server configuration with containerization and services

### Docker Intelligence
- **Automatic Mode Selection**: Rootless by default, root when Swarm/AI-Workspace active
- **Legacy Support**: Backward compatibility with old docker features
- **Smart Detection**: Context-aware Docker configuration

### Legacy Migration
- **Automatic Conversion**: Old packageModules structure to new features
- **Migration Warnings**: User guidance for deprecated configurations
- **Multi-feature Support**: Complex migrations (e.g., virtualization → qemu-vm + virt-manager)

### Metadata System
- **Feature Definitions**: System types, groups, descriptions, dependencies, conflicts
- **Legacy Path Mapping**: Migration support for old package structures
- **Validation Rules**: Automatic constraint checking and error reporting

### Base Package Sets
- **Desktop Base**: Common desktop utilities and applications
- **Server Base**: Minimal server tools and monitoring utilities

### Configuration Options
- **packageModules**: List of features to enable
- **additionalPackageModules**: Extra features beyond presets
- **preset**: Pre-configured package sets
- **Legacy Support**: Backward compatibility with old structures

### Documentation
- Added comprehensive README.md with feature descriptions and usage examples
- Created CHANGELOG.md for version tracking
- Included migration guides and troubleshooting information

### Architecture
- **Modular Design**: Separate concerns for base, features, and presets
- **Metadata-Driven**: Feature behavior defined in centralized metadata
- **Dependency-Aware**: Intelligent package relationship management
- **Migration-Friendly**: Smooth transition from legacy configurations
