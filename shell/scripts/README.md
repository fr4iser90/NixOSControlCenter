# NixOS Homelab Installation Scripts

This directory contains scripts for automating NixOS homelab setup and configuration. The scripts are organized into several key components:

## Directory Structure

```
scripts/
├── checks/            # System verification scripts
├── core/              # Core deployment and initialization
├── lib/               # Shared utilities and functions
├── setup/             # Configuration and setup scripts
└── ui/                # User interface components
```

## Key Workflows

### 1. System Verification
- Hardware checks (CPU, GPU, Memory, Storage)
- System configuration validation (Bootloader, Network, Users)
- Hosting environment verification

### 2. Core Deployment
- `init.sh`: Initializes the NixOS environment
- `deploy-build.sh`: Handles system builds and deployments
- `external-deploy.sh`: Manages external system deployments
- `imports.sh`: Handles configuration imports

### 3. Setup Modes
#### Desktop Mode
- Configures desktop environment
- Sets up user profiles and applications

#### Homelab Mode
- Configures homelab services
- Manages Docker containers
- Sets up homelab-specific configurations

#### Server Mode
- Configures server environment
- Sets up database and container services
- Tests server modules

### 4. User Interface
- Interactive prompts for setup configuration
- Mode selection and validation
- Configuration preview and formatting

## Library Utilities
- `colors.sh`: Terminal color definitions
- `logging.sh`: Logging utilities
- `utils.sh`: Common helper functions
- Security utilities for password checking and permissions
- System dependency management

## System Requirements
- NixOS 23.05 or newer
- Minimum 4GB RAM
- 20GB free disk space
- Network connectivity


