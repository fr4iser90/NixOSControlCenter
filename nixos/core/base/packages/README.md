# Packages System

A core NixOS Control Center module that provides comprehensive package management with feature-based organization, intelligent dependency resolution, and preset configurations.

## Overview

The Packages System module is a **core module** that manages system-wide and user-specific packages for NixOS. It provides a feature-based package organization system with automatic dependency resolution, preset configurations, and intelligent Docker mode selection.

## Features

- **Feature-Based Packages**: Organized by features (gaming, development, virtualization)
- **Intelligent Dependencies**: Automatic dependency resolution and conflict detection
- **Preset Configurations**: Pre-configured package sets for common use cases
- **Docker Intelligence**: Rootless by default; root for Swarm / AI-Workspace (`lib/docker-mode.nix`, override via `docker.root`)
- **System/User Packages**: Separate system-wide and user-specific package management
- **Legacy Support**: Backward compatibility with old packageModules structure
- **CLI Management**: `ncc packages` command for adding/removing packages

## CLI Usage

Add, remove, and list packages via the `ncc packages` CLI:

```bash
# Add a package (defaults to current user)
ncc packages add vscode                    # → userPackages in users/$USER/config.nix
ncc packages add nginx --system            # → systemPackages in core/base/packages/config.nix
ncc packages add firefox --user alice      # → userPackages in users/alice/config.nix

# Remove a package
ncc packages remove vscode                 # ← same default as add
ncc packages remove nginx --system

# List packages
ncc packages list                          # Shows userPackages + systemPackages
ncc packages list --system                 # Shows only systemPackages
```

**Defaults:**
- Operations target the current user's `userPackages` (no flags needed)
- `--system` targets global `systemPackages`
- `--user <name>` overrides the target user

**Config locations:**
- Per-user: `systemConfig/users/<user>/config.nix`
- System: `systemConfig/core/base/packages/config.nix`

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices

## Related Components

- **System Manager**: System type detection
- **Home Manager**: User-specific package management
- **Docker Modules**: Docker configuration integration
