# Configuration Guide

## Overview

NixOSControlCenter uses a declarative configuration system based on Nix expressions. This guide covers all aspects of configuration, from basic settings to advanced customization.

## Configuration Structure

### Main Configuration Files
```
/etc/nixos/
├── configuration.nix          # Main system configuration
├── hardware-configuration.nix # Hardware-specific configuration
├── control-center/
│   ├── main.nix              # NixOSControlCenter main config
│   ├── users.nix             # User configurations
│   ├── network.nix           # Network configuration
│   ├── desktop.nix           # Desktop environment config
│   ├── services.nix          # Service configurations
│   └── features/             # Feature-specific configs
│       ├── ai-workspace.nix
│       ├── homelab.nix
│       ├── ssh.nix
│       └── vm.nix
```

### User Configuration Files
```
~/.config/nixos-control-center/
├── config.yaml               # User preferences
├── themes/                   # Theme configurations
├── shortcuts/                # Keyboard shortcuts
└── profiles/                 # User profiles
```

## Basic Configuration

### System Configuration

#### Main Configuration (`configuration.nix`)
```nix
{ config, pkgs, ... }:

{
  # Import NixOSControlCenter
  imports = [
    ./control-center/main.nix
  ];

  # System settings
  system.stateVersion = "24.11";
  
  # Boot configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Network configuration
  networking.networkmanager.enable = true;
  networking.firewall.enable = true;

  # User configuration
  users.users.youruser = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
  ];
}
```

#### Hardware Configuration (`hardware-configuration.nix`)
```nix
{ config, pkgs, ... }:

{
  # Hardware-specific settings
  hardware = {
    # GPU configuration
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = true;
    };

    # Audio configuration
    pulseaudio.enable = true;

    # Bluetooth
    bluetooth.enable = true;
  };

  # File systems
  fileSystems."/" = {
    device = "/dev/disk/by-uuid/your-uuid";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/boot-uuid";
    fsType = "vfat";
  };
}
```

### NixOSControlCenter Configuration

#### Main Control Center Config (`control-center/main.nix`)
```nix
{ config, pkgs, ... }:

{
  # Enable NixOSControlCenter
  nixos-control-center = {
    enable = true;
    
    # System management
    system = {
      enable = true;
      autoUpdate = true;
      healthMonitoring = true;
    };

    # Package management
    packages = {
      enable = true;
      autoCleanup = true;
      cacheManagement = true;
    };

    # User management
    users = {
      enable = true;
      roleBasedAccess = true;
      passwordPolicy = {
        minLength = 8;
        requireSpecialChars = true;
        requireNumbers = true;
      };
    };

    # Network management
    network = {
      enable = true;
      firewall = {
        enable = true;
        defaultPolicy = "DROP";
      };
      ssh = {
        enable = true;
        port = 22;
        keyAuthentication = true;
      };
    };

    # Hardware management
    hardware = {
      enable = true;
      autoDetection = true;
      gpuSupport = true;
    };
  };
}
```

## Feature-Specific Configuration

### Desktop Environment Configuration

#### GNOME Desktop (`control-center/desktop.nix`)
```nix
{ config, pkgs, ... }:

{
  nixos-control-center.desktop = {
    enable = true;
    environment = "gnome";
    
    gnome = {
      enable = true;
      extensions = [
        "dash-to-dock"
        "arc-menu"
        "weather"
      ];
      
      settings = {
        "org.gnome.desktop.interface" = {
          "enable-hot-corners" = false;
          "show-battery-percentage" = true;
        };
        
        "org.gnome.shell" = {
          "disable-user-extensions" = false;
        };
      };
    };

    themes = {
      enable = true;
      gtkTheme = "Adwaita-dark";
      iconTheme = "Adwaita";
      cursorTheme = "Adwaita";
    };
  };
}
```

#### Plasma Desktop
```nix
{ config, pkgs, ... }:

{
  nixos-control-center.desktop = {
    enable = true;
    environment = "plasma";
    
    plasma = {
      enable = true;
      widgets = [
        "weather"
        "system-monitor"
        "quick-launch"
      ];
      
      settings = {
        "General" = {
          "Name" = "Plasma";
          "ColorScheme" = "BreezeDark";
        };
      };
    };
  };
}
```

### AI Workspace Configuration

#### AI Workspace Setup (`control-center/features/ai-workspace.nix`)
```nix
{ config, pkgs, ... }:

{
  nixos-control-center.features.ai-workspace = {
    enable = true;
    
    # Container configuration
    containers = {
      enable = true;
      engine = "docker";
      
      databases = {
        postgres = {
          enable = true;
          version = "15";
          port = 5432;
        };
        
        vector = {
          enable = true;
          port = 6333;
        };
      };
      
      ollama = {
        enable = true;
        models = [
          "llama2"
          "codellama"
          "mistral"
        ];
      };
    };

    # Training environments
    training = {
      enable = true;
      frameworks = [
        "pytorch"
        "tensorflow"
        "jax"
      ];
      
      gpuSupport = true;
      distributedTraining = true;
    };

    # Services
    services = {
      huggingface = {
        enable = true;
        token = "your-token";
      };
      
      ollama = {
        enable = true;
        apiPort = 11434;
      };
    };
  };
}
```

### Homelab Configuration

#### Homelab Setup (`control-center/features/homelab.nix`)
```nix
{ config, pkgs, ... }:

{
  nixos-control-center.features.homelab = {
    enable = true;
    
    # Service orchestration
    services = {
      enable = true;
      autoStart = true;
      
      containers = {
        enable = true;
        engine = "docker";
        
        services = {
          nginx = {
            enable = true;
            port = 80;
            ssl = true;
          };
          
          postgres = {
            enable = true;
            port = 5432;
            backup = true;
          };
          
          redis = {
            enable = true;
            port = 6379;
          };
        };
      };
    };

    # Monitoring
    monitoring = {
      enable = true;
      
      prometheus = {
        enable = true;
        port = 9090;
      };
      
      grafana = {
        enable = true;
        port = 3000;
      };
      
      alertmanager = {
        enable = true;
        port = 9093;
      };
    };

    # Backup
    backup = {
      enable = true;
      schedule = "daily";
      retention = "30d";
      
      destinations = [
        "/backup/local"
        "/backup/remote"
      ];
    };
  };
}
```

### SSH Configuration

#### SSH Management (`control-center/features/ssh.nix`)
```nix
{ config, pkgs, ... }:

{
  nixos-control-center.features.ssh = {
    enable = true;
    
    # Client configuration
    client = {
      enable = true;
      
      connections = {
        "server1" = {
          host = "192.168.1.100";
          user = "admin";
          port = 22;
          keyFile = "~/.ssh/id_rsa";
        };
        
        "server2" = {
          host = "192.168.1.101";
          user = "admin";
          port = 2222;
          keyFile = "~/.ssh/id_ed25519";
        };
      };
    };

    # Server configuration
    server = {
      enable = true;
      port = 22;
      
      authentication = {
        passwordAuth = false;
        publicKeyAuth = true;
        rootLogin = false;
      };
      
      access = {
        allowedUsers = [ "admin" "user1" "user2" ];
        allowedGroups = [ "ssh-users" ];
      };
      
      monitoring = {
        enable = true;
        logLevel = "INFO";
        maxConnections = 10;
      };
    };
  };
}
```

## Advanced Configuration

### Custom Modules

#### Creating Custom Modules
```nix
# modules/custom-service.nix
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.custom-service;
in {
  options.services.custom-service = {
    enable = mkEnableOption "Custom service";
    
    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port for the service";
    };
    
    config = mkOption {
      type = types.attrs;
      default = {};
      description = "Service configuration";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.custom-service = {
      description = "Custom service";
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        ExecStart = "${pkgs.custom-service}/bin/custom-service";
        Restart = "always";
        RestartSec = 10;
      };
    };
  };
}
```

#### Using Custom Modules
```nix
{ config, pkgs, ... }:

{
  imports = [
    ./modules/custom-service.nix
  ];

  services.custom-service = {
    enable = true;
    port = 9000;
    config = {
      debug = true;
      logLevel = "INFO";
    };
  };
}
```

### Environment Variables

#### System Environment
```nix
{ config, pkgs, ... }:

{
  environment.variables = {
    EDITOR = "vim";
    BROWSER = "firefox";
    TERMINAL = "alacritty";
    
    # Custom variables
    CUSTOM_VAR = "value";
    API_KEY = "your-api-key";
  };

  environment.sessionVariables = {
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_CACHE_HOME = "$HOME/.cache";
  };
}
```

### Security Configuration

#### Security Hardening
```nix
{ config, pkgs, ... }:

{
  nixos-control-center.security = {
    enable = true;
    
    # System hardening
    hardening = {
      enable = true;
      kernelModules = true;
      network = true;
      services = true;
    };
    
    # Firewall rules
    firewall = {
      enable = true;
      defaultPolicy = "DROP";
      
      rules = [
        "INPUT -p tcp --dport 22 -j ACCEPT"
        "INPUT -p tcp --dport 80 -j ACCEPT"
        "INPUT -p tcp --dport 443 -j ACCEPT"
      ];
    };
    
    # Audit logging
    audit = {
      enable = true;
      logLevel = "INFO";
      retention = "30d";
    };
  };
}
```

## Configuration Management

### Configuration Validation

#### Validate Configuration
```bash
# Validate current configuration
nixos-control-center config validate

# Validate specific file
nixos-control-center config validate /etc/nixos/configuration.nix

# Show configuration differences
nixos-control-center config diff
```

#### Configuration Testing
```bash
# Test configuration without applying
nixos-control-center config test

# Dry run configuration changes
nixos-control-center config apply --dry-run

# Preview configuration changes
nixos-control-center config preview
```

### Configuration Backup

#### Backup Configuration
```bash
# Create configuration backup
nixos-control-center config backup

# List available backups
nixos-control-center config backups

# Restore from backup
nixos-control-center config restore backup-2024-01-01

# Show backup information
nixos-control-center config backup info backup-2024-01-01
```

### Configuration Synchronization

#### Sync Configuration
```bash
# Sync configuration to remote system
nixos-control-center config sync remote-server

# Pull configuration from remote
nixos-control-center config pull remote-server

# Show sync status
nixos-control-center config sync status
```

## Best Practices

### Configuration Organization

1. **Modular Structure**: Organize configuration into logical modules
2. **Version Control**: Keep configuration in version control
3. **Documentation**: Document custom configurations
4. **Testing**: Test configurations before applying
5. **Backup**: Regular configuration backups

### Security Considerations

1. **Secrets Management**: Use secure secret management
2. **Access Control**: Implement proper access controls
3. **Audit Logging**: Enable comprehensive audit logging
4. **Regular Updates**: Keep configurations updated
5. **Security Scanning**: Regular security assessments

### Performance Optimization

1. **Resource Limits**: Set appropriate resource limits
2. **Caching**: Enable caching where appropriate
3. **Monitoring**: Monitor configuration performance
4. **Optimization**: Regular performance optimization
5. **Scaling**: Plan for configuration scaling

## Troubleshooting

### Common Issues

#### Configuration Errors
```bash
# Check configuration syntax
nixos-control-center config check

# Show detailed error information
nixos-control-center config errors

# Fix common issues
nixos-control-center config fix
```

#### Configuration Conflicts
```bash
# Detect configuration conflicts
nixos-control-center config conflicts

# Resolve conflicts
nixos-control-center config resolve

# Show conflict history
nixos-control-center config conflicts history
```

### Debugging Configuration

#### Debug Mode
```bash
# Enable debug mode
nixos-control-center config debug

# Show debug information
nixos-control-center config debug info

# Export debug data
nixos-control-center config debug export
```

This configuration guide provides comprehensive coverage of all configuration aspects. For specific feature configurations, refer to the individual feature documentation.
