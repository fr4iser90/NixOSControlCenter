# NixOS Control Center

A graphical tool for managing packages, configurations, and devices on NixOS systems.

## Features (Work in Progress)
- **Bootloader Management**: Configure and manage bootloader entries
  > ⚠️ EXPERIMENTAL: Use with caution - risk of system damage
- **Package Management**: Install, remove, and update packages
  > ⚠️ EXPERIMENTAL: Features under development
- **Configuration Management**: Edit and apply `flakes.nix` and modules
- **System Monitoring**: Monitor resource usage and services
- **Network Management**: Configure connections and firewall rules

## Current Status
This project is under active development. The GUI is not yet implemented, and many features are in experimental state.

## Development Setup
1. Start the development environment:
   ```bash
   nix-shell
   ```
2. Run the program:
   ```bash
   run     #for gui 
   rundebug #for gui with debug mode 
   ```

## Project Structure

```tree
NixOsControlCenter/
├── app/                     # Main application directory
│   ├── nix/                 # App-specific Nix configurations
│   ├── python/              # Python application
│   │   ├── assets/          # Resources (Icons, Images, Themes)
│   │   ├── src/             # Source code
│   │   │   ├── backend/     # Backend logic
│   │   │   ├── frontend/    # Frontend components
│   │   │   └── config/      # Configuration management
│   │   ├── tests/           # Test suites
│   │   └── ui/              # UI definitions
│   └── shell/               # Development environment
│       ├── hooks/           # Shell hooks and aliases
│       └── packages/        # Package definitions
│
├── nixos/                   # NixOS configuration
│   ├── modules/             # Modular system configuration
│   │   ├── audio-management/    # Audio subsystem
│   │   ├── boot-management/     # Boot and kernel
│   │   ├── desktop-management/  # Desktop environments
│   │   ├── hardware-management/ # Hardware drivers
│   │   ├── network-management/  # Network stack
│   │   ├── profile-management/  # System profiles
│   │   ├── user-management/     # User management
│   └── flake.nix            # Nix flake definition
│   └── system-config.nix    # Main system configuration
│
├── docs/                    # Project documentation
│   ├── INSTALL.md           # Installation guide comming soon
│   └── USAGE.md             # User manual comming soon
│  
├── logs/                    # Logging directory
│   └── nixos_error_logs     # System error logs
│
├── CHANGELOG.md             # Change history
├── LICENSE                  # Project license
├── README.md                # Project overview
└── shell.nix                # Main development environment
```