# Changelog

All notable changes to the User System module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-12-09

### Added
- Initial release of the User System core module
- Role-based user account management (admin, restricted-admin, virtualization, guest)
- Automatic group assignment based on user roles
- Dynamic sudo configuration with role-specific permissions
- Password management integration with secure hashed password storage
- Shell integration with automatic system-wide shell activation
- TTY auto-login support for restricted-admin users
- User lingering configuration for systemd user services
- Symlink management for user configuration

### Technical
- Implemented proper MODULE_TEMPLATE structure
- Created modular role-based access control system
- Added symlink management for centralized config access
- Implemented secure password handling with activation scripts
- Added version tracking with `_version` option

### User Roles
- **Admin**: Full system access with passwordless sudo
- **Restricted Admin**: Limited admin access with password prompts and auto-login capability
- **Virtualization**: Specialized for Docker/Podman/VM management with limited sudo
- **Guest**: Basic network access only

### Security Features
- **Password Security**: Hashed password files with proper permissions
- **Sudo Rules**: Role-specific sudo permissions and restrictions
- **Group Management**: Minimal privilege groups based on user roles
- **File Permissions**: Secure activation scripts for password management

### Shell Integration
- **Multi-Shell Support**: Automatic activation of bash, fish, zsh, and other shells
- **System-Level Configuration**: Shells enabled system-wide when used by users
- **User Preferences**: Individual shell configuration per user

### System Integration
- **TTY Auto-Login**: Configurable automatic login for specific users
- **Systemd Lingering**: User service persistence for virtualization role
- **Group Creation**: Dynamic group management for all users
- **Sudo Configuration**: Comprehensive sudo rules based on user roles

### Configuration Options
- **Role Assignment**: Flexible role-based user configuration
- **Shell Selection**: User-specific default shell configuration
- **Auto-Login**: TTY auto-login for restricted-admin users
- **Password Management**: Secure password file handling

### Documentation
- Added comprehensive README.md with role descriptions and configuration examples
- Created CHANGELOG.md for version tracking
- Included security considerations and troubleshooting guides

### Architecture
- **Role-Driven**: User permissions and capabilities based on roles
- **Security-First**: Least privilege access control and secure password handling
- **Modular Design**: Separate components for user management aspects
- **Integration**: Works seamlessly with password-manager and system configuration
