# User System

A comprehensive core NixOS Control Center module that provides user account management, permissions, and system integration. This module handles user creation, group assignments, sudo rules, and shell configurations.

## Overview

The User System module is a **core module** that manages all system user accounts and their permissions. It provides role-based access control, automatic group assignment, sudo configuration, and shell setup.

## Features

- **Role-Based Access Control**: Admin, restricted-admin, virtualization, and guest roles
- **Automatic Group Assignment**: Groups assigned based on user roles
- **Sudo Configuration**: Role-specific sudo rules and permissions
- **Password Management**: Secure password handling with hashed passwords
- **Shell Integration**: Automatic shell activation based on user preferences
- **TTY Auto-Login**: Configurable automatic login for specific users

## Architecture

### File Structure

```
user/
├── README.md                    # This documentation
├── CHANGELOG.md                 # Version history
├── default.nix                  # Main module entry point
├── options.nix                  # Configuration options
├── config.nix                   # Implementation logic & symlink management
├── user-config.nix              # User configuration (symlinked)
├── password-manager.nix         # Password management system
└── home-manager/                # User environment management
    ├── roles/                   # Role definitions
    │   ├── admin.nix           # Administrator role
    │   ├── restricted-admin.nix # Limited admin role
    │   ├── virtualization.nix  # Virtualization user role
    │   └── guest.nix           # Guest user role
    └── shellInit/               # Shell initialization
        ├── bashInit.nix        # Bash shell setup
        ├── fishInit.nix        # Fish shell setup
        ├── zshInit.nix         # Zsh shell setup
        └── ...                 # Other shells
```

### User Roles

#### Admin (`role = "admin"`)
- **Groups**: wheel, networkmanager, docker, podman, video, audio, render, input, seat
- **Sudo**: Full access without password prompt
- **Description**: Complete system administrator access

#### Restricted Admin (`role = "restricted-admin"`)
- **Groups**: wheel, networkmanager, video, audio
- **Sudo**: Full access with password prompt
- **Auto-Login**: Can be configured for TTY auto-login
- **Description**: Limited administrative access with restrictions

#### Virtualization (`role = "virtualization"`)
- **Groups**: docker, podman, libvirtd, kvm
- **Sudo**: Limited to Docker Swarm and node commands (passwordless)
- **Lingering**: Enabled for systemd user services
- **Description**: Specialized for container and VM management

#### Guest (`role = "guest"`)
- **Groups**: networkmanager
- **Sudo**: No sudo access
- **Description**: Basic user access with network permissions only

## Configuration

Users are configured centrally in `system-config.nix`:

```nix
{
  users = {
    alice = {
      role = "admin";
      defaultShell = "zsh";
      autoLogin = false;
    };

    bob = {
      role = "restricted-admin";
      defaultShell = "fish";
      autoLogin = true;  # Enables TTY auto-login
    };

    charlie = {
      role = "virtualization";
      defaultShell = "bash";
    };

    guest = {
      role = "guest";
      defaultShell = "bash";
    };
  };
}
```

## Technical Details

### User Creation

The module automatically creates users based on `systemConfig.core.base.user`:

- **User Accounts**: Created with appropriate home directories
- **Group Membership**: Automatic assignment based on role
- **Shell Setup**: Configures default shell and enables system-wide shell support
- **Password Management**: Integrates with password-manager for secure password handling

### Group Management

Dynamic group creation and assignment:

- **User Groups**: Each user gets their own group
- **Role Groups**: Additional groups based on user role
- **System Groups**: Pre-defined groups for system access

### Sudo Configuration

Role-specific sudo rules:

- **Admin**: `ALL` commands without password
- **Restricted Admin**: `ALL` commands with password
- **Virtualization**: Specific Docker commands without password
- **Guest**: No sudo access

### Shell Integration

Automatic shell activation:

- **System Level**: Enables shells system-wide when used by users
- **User Level**: Sets default shell for each user account
- **Initialization**: Shell-specific initialization scripts

### Password Security

Integration with password-manager:

- **Hashed Passwords**: Secure password storage
- **File-Based**: Passwords stored in `/etc/nixos/secrets/passwords/`
- **Permission Management**: Proper file permissions and ownership
- **Activation Scripts**: Automatic permission setup during system activation

### TTY Auto-Login

Configurable automatic login:

- **Eligibility**: Only for `restricted-admin` role
- **Configuration**: Set `autoLogin = true` in user config
- **Systemd Service**: Automatic agetty configuration for TTY1

## Security Considerations

### Principle of Least Privilege

- **Role-Based**: Users get only necessary permissions
- **Minimal Groups**: Only required groups assigned
- **Sudo Restrictions**: Limited sudo access where appropriate

### Password Management

- **Secure Storage**: Hashed passwords in protected directory
- **File Permissions**: Restricted access (600, owner-only)
- **Activation Security**: Permissions set during system activation

### Service Access Control

- **Lingering**: Only enabled for virtualization role
- **Group Restrictions**: Access limited to necessary system groups
- **Sudo Auditing**: Password requirements for sensitive operations

## Development

This module follows the unified MODULE_TEMPLATE architecture:

- **Role-Driven**: User permissions based on roles
- **Security-First**: Least privilege access control
- **Modular Design**: Separate components for different user aspects
- **Integration**: Works with password-manager and other system components

## Related Components

- **Password Manager**: Secure password handling (`password-manager.nix`)
- **Home Manager**: User environment management (`home-manager/`)
- **System Config**: Central user configuration (`system-config.nix`)

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions (if available)
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices (if available)
- [Security](./doc/SECURITY.md) - Security considerations and threat model (if available)

## Troubleshooting

### Common Issues

1. **Login Issues**: Check user role and group assignments
2. **Sudo Problems**: Verify role-specific sudo rules
3. **Shell Errors**: Ensure shell is properly configured
4. **Password Issues**: Check password file permissions

### Debug Commands

```bash
# Check user groups
groups username

# Check sudo rules
sudo -l -U username

# Check user shell
getent passwd username

# Check password file
ls -la /etc/nixos/secrets/passwords/username/
```
