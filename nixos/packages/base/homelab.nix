{ config, lib, pkgs, systemConfig, ... }:

{
  # Basic configuration for Homelab setup
  services.openssh.enable = true;  # Enable SSH server for remote access
  virtualisation.docker.enable = true;  # Enable Docker container support
  
  # Enable Firefox only if desktop environment is enabled
  programs.firefox.enable = systemConfig.desktop.enable or false;

  # Prevent system from going to sleep
  powerManagement.enable = false;  # Disable power management features
  services.logind.extraConfig = ''
    HandleLidSwitch=ignore  # Ignore laptop lid close events
    HandleLidSwitchExternalPower=ignore  # Ignore lid close when on AC power
    IdleAction=ignore  # Disable automatic suspend on idle
    IdleActionSec=0  # Set idle timeout to 0 seconds
    SuspendKeyIgnoreInhibited=yes  # Allow suspend key even when inhibited
    HibernateKeyIgnoreInhibited=yes  # Allow hibernate key even when inhibited
    LidSwitchIgnoreInhibited=yes  # Allow lid switch even when inhibited
  '';

  # System packages to install
  environment.systemPackages = with pkgs; [
    docker          # Docker container runtime
    docker-client   # Docker CLI client
    coreutils       # Basic file, shell, and text manipulation utilities
    curl            # Command-line tool for transferring data with URLs
    wget            # Command-line utility for downloading files from the web
    git             # Distributed version control system
    neovim          # Modern text editor for configuration and scripting
    htop            # Interactive process viewer
    tmux            # Terminal multiplexer for managing multiple terminal sessions
    tree            # Display directory structures in a tree-like format
    fzf             # Fuzzy finder for quick file and command searching
    iotop           # Monitor disk I/O usage by processes
    iftop           # Display real-time bandwidth usage by network connections
    ufw             # Uncomplicated Firewall for managing firewall rules
    nmap            # Network scanner for auditing and monitoring networks
    gnupg           # Encryption and signing tool for secure communications
  ];
}
