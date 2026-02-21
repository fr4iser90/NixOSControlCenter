# Lock Manager

A module that provides system discovery, documentation, and secure storage of system state. It captures desktop settings, installed software, credential metadata, and more.

## Overview

The Lock Manager (System Discovery) module enables automatic scanning, documentation, and secure storage of your entire system state. It captures desktop settings, installed software (including Steam games), credential metadata, and more.

## Quick Start

```nix
{
  enable = true;
  snapshotDir = "/var/lib/nixos-control-center/snapshots";
  scanners = {
    desktop = true;
    steam = true;
    browser = true;
    ide = true;
    credentials = true;
    packages = true;
  };
}
```

## Features

- **Automatic System Scanning**: Captures all important system settings
- **Steam Game Detection**: Finds all installed Steam games
- **Desktop Settings**: Dark mode, themes, cursor, icons, GTK, fonts, wallpapers
- **Browser State**: Extensions, bookmarks, and settings for Firefox, Chrome, Chromium
- **IDE Configuration**: Extensions, plugins, and settings for VS Code, JetBrains IDEs, Neovim/Vim
- **Secure Credential Management**: Metadata from SSH/GPG keys (no private keys by default)
- **Package Detection**: NixOS, Flatpak, and other packages
- **Encryption**: Supports sops-nix and FIDO2/YubiKey
- **GitHub Upload**: Automatic upload to private repositories

## Documentation

For detailed documentation, see:
- [Architecture](./doc/ARCHITECTURE.md) - System architecture and design decisions
- [Usage Guide](./doc/USAGE.md) - Detailed usage examples and best practices
- [Security](./doc/SECURITY.md) - Security considerations and threat model

## Related Components

- **System Manager**: System-level management
- **User Module**: User account management
