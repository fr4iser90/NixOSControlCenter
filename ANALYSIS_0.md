## Probably Goal

nixos/
├── core/                    # Foundation system (always active)
│   ├── system/  
│   │   ├── boot/           # Always (can't boot without)
│   │   ├── hardware/       # Always (kernel modules needed)  
│   │   ├── user/           # Always (can't login without)
│   │   ├── network/        # Always (updates need internet)
│   │   ├── packages/       # Always (basic tools needed)
│   │   ├── desktop/        # Always (GUI expected for desktop)
│   │   ├── audio/          # Always (multimedia expected)
│   │   └── localization/   # Always (international support)
│   ├── management/
│   │   ├── system-manager/    # Config-Management + CLI-APIs + Updates
│   │   │   ├── cli-formatter/ # SUBMODULE: UI formatting
│   │   │   ├── cli-commands/  # SUBMODULE: CLI command registration
│   │   │   ├── system-update/ # SUBMODULE: update logic
│   │   │   ├── system-checks/ # SUBMODULE: system validation
│   │   │   └── system-logging/# SUBMODULE: system reports
│   │   └── module-manager/   # Modul-Management (Discovery/Aktivierung)  
│   └── default.nix
├── modules/                 # Extended modules (configurable)
│   ├── security/           # Domain: Security
│   │   ├── ssh-client-manager/
│   │   ├── ssh-server-manager/
│   │   └── lock-manager/
│   ├── infrastructure/     # Domain: Infrastructure (Features)
│   │   ├── homelab-manager/
│   │   └── vm-manager/
│   └── specialized/        # Domain: Specialized
│       ├── ai-workspace/
│       └── hackathon/
└── flake.nix



