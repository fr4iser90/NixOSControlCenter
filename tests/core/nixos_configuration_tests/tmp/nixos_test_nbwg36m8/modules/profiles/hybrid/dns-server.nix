{ config, lib, pkgs, ... }:

{
  # Default Shell
  users.defaultUserShell = lib.mkForce pkgs.zsh;
  
  # Development Server Packages
  environment.systemPackages = with pkgs; [
    # IDEs and Editors
    vscode
    jetbrains.idea-ultimate
    sublime4
    neovim
    
    # Development Tools
    git
    git-lfs
    gitAndTools.gh
    docker-compose
    postman
    insomnia
    
    # Languages and Runtimes
    nodejs
    python3Full
    go
    rustc
    cargo
    jdk17
    
    # Build Tools
    gcc
    cmake
    gnumake
    
    # Database Tools
    dbeaver
    mongodb-compass
    pgadmin4
    
    # System Tools
    kitty
    kate
    htop
    iotop
    
    # Monitoring
    grafana
    prometheus
    netdata
  ];

  # Virtualization
  virtualisation = {
    docker = {
      enable = true;
      enableOnBoot = true;
      autoPrune.enable = true;
    };
    libvirtd.enable = true;
  };

  # Services
  services = {
    # Database Services
    postgresql = {
      enable = true;
      package = pkgs.postgresql_15;
    };
    
    mongodb = {
      enable = true;
      package = pkgs.mongodb;
    };

    # Monitoring
    grafana = {
      enable = true;
      settings.server.http_port = 3000;
    };

    prometheus = {
      enable = true;
      exporters = {
        node.enable = true;
        systemd.enable = true;
      };
    };
  };

  # Shell Configuration
  programs = {
    zsh = {
      enable = lib.mkForce true;
      enableCompletion = true;
      autosuggestions.enable = true;
      syntaxHighlighting.enable = true;
    };

    git = {
      enable = true;
      config = {
        credential.helper = "manager";
      };
    };
  };

  # Network Configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 
      5432  # PostgreSQL
      27017 # MongoDB
      3000  # Grafana
      9090  # Prometheus
    ];
  };
}