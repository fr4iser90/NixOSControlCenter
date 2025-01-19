## Features Configuration

The features configuration module provides a modular way to enable and configure various system features in NixOS. Features are enabled through `systemConfig.features`.

### Feature Activation

Features are automatically activated based on their configuration in `systemConfig.features`. The module checks if any feature is active using `hasActiveFeatures`.

### Core Components

When any feature is active, the following core components are automatically loaded:
- Terminal UI
- Command Center

### Available Features

1. **System Checks**
   - Pre-build and post-build system validation

2. **System Updater**
   - Git/Local system updates and maintenance

3. **System Logger**
   - Centralized logging and monitoring

4. **Container Manager**
   - Docker, Podman, and OCI container management
   - Integrated with Homelab Manager when enabled

5. **Homelab Manager**
   - Specialized container and service management for homelab environments
   - Automatically enables Container Manager

6. **Bootentry Manager**
   - Bootloader entry management and configuration

7. **SSH Client Manager**
   - SSH client configuration and connection management

8. **SSH Server Manager**
   - SSH server configuration and monitoring

9. **VM Manager**
   - Virtual machine creation and management
   - Includes ISO management and testing tools

10. **AI Workspace**
    - AI/ML development environment
    - Includes LLM tools and services

### Special Configuration

- **Homelab System**: Special handling when `systemConfig.systemType` is set to "homelab"
- **Nix Experimental Features**: Enables `nix-command` and `flakes` features

### Configuration Options

Each feature can be enabled through `systemConfig.features`:
```nix
systemConfig.features = {
  system-checks = true;
  system-updater = true;
  # ... other features
};
```
