# NixOS Concepts Dataset Structure

This directory contains structured datasets for NixOS concepts, organized in a progressive learning path from fundamentals to advanced deployment.

## Directory Structure

```
concepts/
├── 00_fundamentals/           # Foundation concepts
│   ├── 01_core_concepts      # NixOS philosophy, principles
│   ├── 02_architecture       # System architecture
│   ├── 03_package_basics     # Basic package management
│   └── 04_workflow_basics    # Common workflows
├── 01_configuration/         # System configuration
│   ├── 01_system_config     # configuration.nix basics
│   ├── 02_modules           # Module system
│   ├── 03_options           # NixOS options
│   └── 04_hardware_config   # Hardware configuration
├── 02_package_management/    # Package management
│   ├── 01_nixpkgs          # Nixpkgs collection
│   ├── 02_overlays         # Package customization
│   ├── 03_flakes           # Modern package management
│   └── 04_packaging        # Creating packages
├── 03_system_administration/ # System administration
│   ├── 01_services         # Service management
│   ├── 02_networking       # Network configuration
│   ├── 03_security        # Security features
│   └── 04_maintenance     # System maintenance
├── 04_user_management/      # User management
│   ├── 01_user_env        # User environments
│   ├── 02_home_manager    # Home Manager
│   ├── 03_dotfiles        # Configuration files
│   └── 04_permissions     # User permissions
├── 05_development/         # Development
│   ├── 01_dev_env        # Development environments
│   ├── 02_languages      # Language support
│   ├── 03_tools         # Development tools
│   └── 04_debugging     # Debugging and testing
└── 06_deployment/         # Deployment
    ├── 01_containers    # Container integration
    ├── 02_cloud        # Cloud deployment
    ├── 03_automation   # CI/CD, automation
    └── 04_monitoring   # System monitoring
```

## Dataset Format

Each `.jsonl` file contains a collection of concepts in JSON Lines format:

```json
{
  "concept": "What is X?",
  "explanation": "[Category] Detailed explanation...",
  "examples": ["Optional example 1", "Optional example 2"],
  "references": ["Optional reference 1", "Optional reference 2"]
}
```

## Categories

1. **Fundamentals**: Core NixOS concepts and basic usage
2. **Configuration**: System configuration and module system
3. **Package Management**: Package handling and customization
4. **System Administration**: System maintenance and security
5. **User Management**: User environments and configuration
6. **Development**: Development environments and tools
7. **Deployment**: Deployment and infrastructure

## Learning Path

The numbered directories (00-06) represent a recommended learning path, from basic to advanced concepts. Users should generally progress through these in order for the best learning experience.