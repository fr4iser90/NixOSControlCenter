# server-profile.nix
{ config, lib, pkgs, ... }:
{
  # Installing essential CLI tools for server management
  environment.systemPackages = with pkgs; [
    coreutils   # Basic file, shell, and text manipulation utilities
    curl        # Command-line tool for transferring data with URLs
    wget        # Command-line utility for downloading files from the web
    git         # Distributed version control system
    neovim      # Modern text editor for configuration and scripting
    htop        # Interactive process viewer
    unzip
    tmux        # Terminal multiplexer for managing multiple terminal sessions
    tree        # Display directory structures in a tree-like format
    fzf         # Fuzzy finder for quick file and command searching
    iotop       # Monitor disk I/O usage by processes
    iftop       # Display real-time bandwidth usage by network connections
    # ufw package not present in this nixpkgs revision; remove to avoid build failure
    nmap        # Network scanner for auditing and monitoring networks
    gnupg       # Encryption and signing tool for secure communications
    jq
  ];

  # Enable OpenSSH for remote access to the server
  services.openssh.enable = true;
}
