# NixOS Control Center

A comprehensive tool for managing packages, configurations, and devices on NixOS systems with a focus on reproducibility and declarative configurations. Quick install desktop, server or whole homelab setup in less then 5 Minutes.

> ⚠️ EXPERIMENTAL: This project is under active development

## Key Features

- **System Configuration Management**: Declarative system configuration through Nix expressions
- **Package Management**: Unified package management interface
- **Device Management**: Hardware configuration and monitoring
- **Modular Architecture**: Extensible through Nix modules
- **Development Environment**: Integrated development shell with all dependencies

## Installation

### System Requirements
- NixOS (tested on 24.11)
- systemd-boot
- Supported GPUs: AMD, Intel, NVIDIA-Intel

### Quick Install
```bash
git clone https://github.com/fr4iser90/NixOSControlCenter
cd NixOSControlCenter
sudo nix-shell install-shell.nix
install
```

For detailed installation instructions, see [INSTALL.md](docs/INSTALL.md)

## Development Setup

1. Start development shell:
```bash
nix-shell dev-shell.nix
```

2. Available commands:
```bash
show-help
```

For more details, see [DEVELOPMENT.md](docs/DEVELOPMENT.md)

## Project Structure

The project is organized into these main components:

- **app/**: Main application code
  - `modules/`: App-specific modules
  - `python/`: Python application
    - `src/`: Source code
      - `backend/`: Backend services and models
      - `config/`: Configuration files
      - `frontend/`: Frontend components
    - `tests/`: Test suites
    - `ui/`: UI definitions and components
  - `shell/`: Shell environments
    - `dev/`: Development environment
    - `install/`: Installation environment

- **docs/**: Project documentation
  - `DEVELOPMENT.md`: Development setup
  - `INSTALL.md`: Installation guide
  - `PROJECT_STRUCTURE.md`: Detailed structure
  - `USAGE.md`: Usage instructions

- **nixos/**: NixOS configurations
  - `core/`: Core system functionality
    - `boot/`: Bootloader configuration
    - `hardware/`: Hardware-specific settings
    - `network/`: Network configuration
    - `system/`: System management
    - `user/`: User management
  - `desktop/`: Desktop environment
    - `audio/`: Audio configuration
    - `display-managers/`: Display managers
    - `display-servers/`: Display servers
    - `environments/`: Desktop environments
    - `themes/`: Visual customization
  - `features/`: System features
    - `ai-workspace/`: AI development tools
    - `container-manager/`: Container management
    - `homelab-manager/`: Homelab configuration
    - `ssh-client-manager/`: SSH client management
    - `system-checks/`: System validation
  - `packages/`: System packages
    - `base/`: Base system packages
    - `modules/`: Package modules

For complete project structure, see [PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md)

## Hardware Compatibility

✅ AMD GPU  
✅ Intel GPU  
✅ NVIDIA-Intel GPU  
✅ systemd-boot  

## Project Status

- **GUI**: In Development
- **Documentation**: In Progress
- **Testing**: In Progress
- **CI/CD**: Planned
- **Docker to Nix**: Planned

## Support the Project

If you find this project useful, please consider supporting its development:

[![Donate with PayPal](https://www.paypalobjects.com/en_US/i/btn/btn_donate_SM.gif)](https://www.paypal.me/SupportMySnacks)

Your support helps cover development costs and keeps the project actively maintained.

## License

This project is licensed under the terms of the [LICENSE](LICENSE) file.
