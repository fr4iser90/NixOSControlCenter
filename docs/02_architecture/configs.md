configs/
├── core/
│   ├── management/
│   │   ├── module-manager/
│   │   │   └── config.nix
│   │   └── system-manager/
│   │       ├── config.nix
│   │       └── submodules/
│   │           ├── system-logging/
│   │           │   └── config.nix
│   │           ├── system-update/
│   │           │   └── config.nix
│   │           ├── cli-formatter/
│   │           │   └── config.nix
│   │           ├── cli-registry/
│   │           │   └── config.nix
│   │           └── system-checks/
│   │               └── config.nix
│   └── base/
│       ├── audio/
│       │   └── config.nix
│       ├── boot/
│       │   └── config.nix
│       ├── desktop/
│       │   └── config.nix
│       ├── hardware/
│       │   └── config.nix
│       ├── localization/
│       │   └── config.nix
│       ├── network/
│       │   └── config.nix
│       ├── packages/
│       │   └── config.nix
│       └── user/
│           └── config.nix
├── modules/
│   ├── infrastructure/
│   │   ├── bootentry-manager/
│   │   │   └── config.nix
│   │   ├── homelab-manager/
│   │   │   └── config.nix
│   │   └── vm/
│   │       └── config.nix
│   ├── security/
│   │   ├── ssh-client-manager/
│   │   │   └── config.nix
│   │   └── ssh-server-manager/
│   │       └── config.nix
│   └── specialized/
│       ├── ai-workspace/
│       │   └── config.nix
│       └── hackathon/
│           └── config.nix 
└── users/
    ├── user1/
    │   ├─ packages.nix    # Überschreibt system.packages
    │   └── desktop.nix     # Überschreibt system.desktop
    ├── user2/
    │   ├─ packages.nix    # Überschreibt system.packages
    │   └── desktop.nix     # Überschreibt system.desktop
    └── user3/
        ├── packages.nix    # Überschreibt system.packages
        └── desktop.nix     # Überschreibt system.desktop
