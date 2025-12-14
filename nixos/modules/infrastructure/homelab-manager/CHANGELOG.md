# Changelog

All notable changes to the Homelab Manager feature module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-12-09

### Added
- Initial release of the Homelab Manager feature module
- Docker-based homelab environment management
- Support for both single-server and Docker Swarm modes
- Docker Compose stack configuration and management
- User-based Docker access control (virtualization vs admin roles)
- Symlink management for user configuration
- Command-line tools for homelab operations

### Technical
- Implemented proper MODULE_TEMPLATE structure
- Created comprehensive Docker and container management
- Added symlink management for centralized config access
- Implemented user role-based access control
- Added version tracking with `_version` option

### Docker Integration
- **Single-Server Mode**: Individual Docker host management
- **Swarm Mode**: Multi-node Docker Swarm support (manager/worker)
- **User Access Control**: Role-based Docker permissions
- **Stack Management**: Docker Compose stack deployment

### Command-Line Tools
- **homelab-create**: Create homelab environments
- **homelab-fetch**: Fetch stack definitions and configurations
- **homelab-minimize**: Convert desktop to server configuration
- **homelab-status**: Display homelab status (planned)
- **homelab-update**: Update stacks and configurations (planned)
- **homelab-delete**: Remove homelab environments (planned)

### User Role Integration
- **Virtualization Users**: Preferred for Docker/Swarm operations
- **Admin Users**: Fallback for single-server mode (not Swarm)
- **Automatic Detection**: Smart user role selection based on configuration
- **Security**: Proper permission management and access control

### Configuration Features
- **Stack Definitions**: Docker Compose stack configurations
- **Environment Variables**: Support for .env files
- **Swarm Configuration**: Manager/worker node specification
- **Service Dependencies**: Automatic Docker and git installation

### System Integration
- **Activation Scripts**: Symlink management during system activation
- **Package Management**: Automatic Docker and tool installation
- **User Permissions**: Proper group assignments for Docker access
- **Command Registration**: Integration with command-center

### Documentation
- Added comprehensive README.md with usage examples
- Created CHANGELOG.md for version tracking
- Included configuration examples and command descriptions

### Architecture
- **Modular Design**: Separate scripts for different operations
- **Role-Based Security**: User permission management
- **Swarm-Aware**: Context-sensitive configuration based on Swarm mode
- **Extensible**: Easy addition of new homelab features and stacks
