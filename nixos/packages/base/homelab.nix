{ config, lib, pkgs, systemConfig, ... }:

{
  # Basic configuration for Homelab setup
  services.openssh.enable = true;  # Enable SSH server for remote access
  virtualisation.docker.enable = true;  # Enable Docker container support
  
  # Enable Firefox only if desktop environment is enabled
  programs.firefox.enable = systemConfig.desktop.enable or false;

  # System packages to install
  environment.systemPackages = with pkgs; [
    docker          # Docker container runtime
    docker-client   # Docker CLI client
    coreutils       # Basic file, shell, and text manipulation utilities
    curl            # Command-line tool for transferring data with URLs
    wget            # Command-line utility for downloading files from the web
    unzip
    git             # Distributed version control system
    neovim          # Modern text editor for configuration and scripting
    htop            # Interactive process viewer
    tmux            # Terminal multiplexer for managing multiple terminal sessions
    tree            # Display directory structures in a tree-like format
    fzf             # Fuzzy finder for quick file and command searching
    iotop           # Monitor disk I/O usage by processes
    iftop           # Display real-time bandwidth usage by network connections
    nmap            # Network scanner for auditing and monitoring networks
    gnupg           # Encryption and signing tool for secure communications
  ];
}
