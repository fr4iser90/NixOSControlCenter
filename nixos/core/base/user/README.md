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

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices
- [Security](./doc/SECURITY.md) - Security considerations and threat model

## Related Components

- **Password Manager**: Secure password handling
- **Home Manager**: User environment management
- **System Config**: Central user configuration
