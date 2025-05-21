# NixOS Control Center

A comprehensive tool for managing packages, configurations, and devices on NixOS systems with a focus on reproducibility and declarative configurations. Quick install desktop, server or whole homelab setup in less then 5 Minutes.

> ⚠️ EXPERIMENTAL: This project is under active development

## Key Features

- **System Configuration Management**: Declarative system configuration through Nix expressions
- **Package Management**: Unified package management interface
- **Device Management**: Hardware configuration and monitoring
- **Modular Architecture**: Extensible through Nix modules

## Installation

### System Requirements
- NixOS (tested on 24.11)

### Quick Install
```bash
git clone https://github.com/fr4iser90/NixOSControlCenter.git
cd NixOSControlCenter
sudo nix-shell
```

## Project Structure

<details>
<summary>Click to expand</summary>

The project is organized into these main components:

- **nixos/**: NixOS configurations
  - `core/`: Core system functionality
    - `boot/`: Bootloader configuration
    - `hardware/`: Hardware-specific settings
    - `network/`: Network configuration
    - `system/`: System management
    - `user/`: User management
  - `custom/`: Custom configurations
  - `desktop/`: Desktop environment
    - `audio/`: Audio configuration
    - `display-managers/`: Display managers
    - `display-servers/`: Display servers
    - `environments/`: Desktop environments
    - `themes/`: Visual customization
  - `features/`: System features
    - `ai-workspace/`: AI development tools
    - `bootentry-manager/`: Boot entry management
    - `command-center/`: Command center
    - `homelab-manager/`: Homelab configuration
    - `ssh-client-manager/`: SSH client management
    - `ssh-server-manager/`: SSH server management
    - `system-checks/`: System validation
    - `system-config-manager/`: System configuration management
    - `system-logger/`: System logging
    - `system-updater/`: System updates
    - `terminal-ui/`: Terminal UI components
    - `vm-manager/`: VM management
  - `packages/`: System packages
    - `base/`: Base system packages
    - `modules/`: Package modules

- **shell/**: Shell environments and scripts
  - `homelab/`: Homelab management scripts
  - `hooks/`: Shell hooks
  - `packages/`: Shell package definitions
  - `scripts/`: Various utility scripts

- **docs/**: Project documentation
  - `DEVELOPMENT.md`: Development setup
  - `INSTALL.md`: Installation guide
  - `PROJECT_STRUCTURE.md`: Detailed structure
  - `USAGE.md`: Usage instructions

</details>

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
