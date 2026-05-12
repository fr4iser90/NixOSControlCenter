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
- **Per-User Configs**: User-specific overrides for packages, home-manager, and system settings

## Configuration

### Central User Config (Fallback)

Basic user definitions go in `systemConfig/core/base/user/config.nix`:

```nix
{
  users = {
    "fr4iser" = {
      role = "admin";
      defaultShell = "zsh";
      autoLogin = false;
    };
  };
}
```

### Per-User Configs (Recommended)

User-specific overrides go in `systemConfig/users/<username>/config.nix`:

```
systemConfig/
  users/
    fr4iser/
      config.nix          # Per-user: packages, home-manager, overrides
    alice/
      config.nix
```

**Per-user config supports ALL NixOS options:**

```nix
# systemConfig/users/fr4iser/config.nix

# User packages (per-user, not global)
userPackages = [ "vscode" "firefox" ];

# System packages for this user only
environment.systemPackages = [ "git" "neovim" ];

# Home Manager config
programs.git = {
  userName = "Your Name";
  userEmail = "you@example.com";
};

# System overrides
services.openssh.enable = true;
networking.firewall.allowedTCPPorts = [ 22 ];
```

**Priority:** Per-user configs override central user config.

## User Roles

| Role | Groups | Sudo | Description |
|------|--------|------|-------------|
| `admin` | wheel, networkmanager, docker, podman, video, audio, render, input, seat | NOPASSWD ALL | Full system admin |
| `restricted-admin` | wheel, networkmanager, video, audio | PASSWD ALL | Limited admin |
| `virtualization` | docker, podman, libvirtd, kvm | docker swarm/node only | Docker/VM management |
| `guest` | networkmanager | none | Read-only access |

## Directory Structure

```
nixos/core/base/user/
  default.nix                   # Module entry point
  config.nix                    # User creation logic
  options.nix                   # Module options
  password-manager.nix          # Password handling
  api.nix                       # Permission API
  template-config.nix           # Template for central config
  template-per-user-config.nix  # Template for per-user configs
  migrate-to-per-user-config.sh # Migration script
  home-manager/                 # Home manager roles
    roles/                      # Role-specific home manager configs
```

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices
- [Security](./doc/SECURITY.md) - Security considerations and threat model

## Related Components

- **Password Manager**: Secure password handling
- **Home Manager**: User environment management
- **System Config**: Central user configuration
- **Package System**: Feature-based package management
