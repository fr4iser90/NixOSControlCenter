# Project Structure

```tree

NixOsControlCenter/
├── app/
│ ├── modules/ # App-specific modules
│ ├── nix/ # App-specific Nix configurations
│ ├── python/ # Python application
│ │ ├── assets/ # Resources (icons, images, themes)
│ │ ├── src/ # Source code
│ │ ├── tests/ # Test suites
│ │ └── ui/ # UI definitions
│ └── shell/ # Shell environments
│ ├── dev/ # Development environment
│ └── install/ # Installation environment
│
├── docs/ # Documentation
│ ├── DEVELOPMENT.md
│ ├── INSTALL.md
│ ├── PROJECT_STRUCTURE.md
│ └── USAGE.md
│
├── nixos/ # NixOS configuration
│ ├── modules/ # System modules
│ │ ├── core/ # Core system functionality
│ │ │ ├── boot/ # Boot and bootloader management
│ │ │ ├── hardware/ # Hardware configuration
│ │ │ ├── network/ # Network configuration
│ │ │ ├── system/ # System management
│ │ │ └── user/ # User management
│ │ │
│ │ ├── desktop/ # Desktop environment
│ │ │ ├── audio/ # Audio configuration
│ │ │ ├── display-managers/
│ │ │ ├── display-servers/
│ │ │ ├── environments/
│ │ │ └── themes/ # Visual customization
│ │ │
│ │ └── services/ # System services
│ │ ├── cli/ # Command-line tools
│ │ ├── homelab/ # Homelab configuration
│ │ ├── log/ # Logging system
│ │ ├── ssh/ # SSH configuration
│ │ └── virtualization/ # VM and container management
│ │
│ ├── packages/ # System packages and profiles
│ │ ├── base/ # Base system configurations
│ │ ├── custom/ # Custom configurations
│ │ └── modules/ # Package modules
│ │
│ ├── local/ # Local overrides
│ ├── flake.nix # Main Nix flake
│ └── system-config.nix # System configuration
│
├── CHANGELOG.md
├── dev-shell.nix # Development shell configuration
├── install-shell.nix # Installation shell configuration
├── LICENSE
└── README.md