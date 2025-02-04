# Core Modules

The core modules provide essential system configuration for NixOS systems. These modules are imported by the main system configuration and handle fundamental system aspects.

## Modules

### 1. Boot (`boot/`)
- Manages bootloader configuration and kernel settings
- Supports systemd-boot, GRUB, and rEFInd bootloaders
- Configures initrd with Zstandard compression
- Uses latest Linux kernel packages
- Enables systemd in initrd

### 2. Hardware (`hardware/`)
- Aggregates hardware-specific configurations
- Includes submodules for:
  - GPU configuration
  - CPU settings
  - Memory management

### 3. Network (`network/`)
- Provides core networking functionality
- Features:
  - NetworkManager integration
  - Basic firewall configuration
  - Hostname and timezone management
  - Conditional wireless and DNS configurations

### 4. System (`system/`)
- Handles system-wide settings including:
  - Locale configuration (default: en_US.UTF-8)
  - German locale settings for specific categories
  - Console keymap configuration

### 5. User (`user/`)
- Manages user accounts and permissions
- Features:
  - Role-based user management (admin, guest, restricted-admin, virtualization)
  - Role-specific package installations
  - Sudo rules configuration
  - Auto-login capabilities
  - Password management integration
  - Shell configuration (zsh, fish)

Each module can be configured through `systemConfig` parameters.
