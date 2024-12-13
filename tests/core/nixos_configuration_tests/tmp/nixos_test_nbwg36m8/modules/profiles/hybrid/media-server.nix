{ config, lib, pkgs, ... }:

{
  # Default Shell
  users.defaultUserShell = lib.mkForce pkgs.zsh;
  
  # Media Server Packages
  environment.systemPackages = with pkgs; [
    # Media Server Software
    plex
    jellyfin
    emby
    sonarr
    radarr
    jackett
    transmission
    
    # Transcoding Tools
    ffmpeg
    handbrake
    mediainfo
    
    # Monitoring & Management
    grafana
    prometheus
    netdata
    htop
    iotop
    
    # System Tools
    kitty
    kate
    pavucontrol
    filebot  # Media file organization
    
    # Remote Access
    remmina
    anydesk
  ];

  # Services
  services = {
    # Media Servers
    plex = {
      enable = true;
      openFirewall = true;
    };
    
    jellyfin = {
      enable = true;
      openFirewall = true;
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
  };

  # Network Configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 
      32400  # Plex
      8096   # Jellyfin
      8989   # Sonarr
      7878   # Radarr
      9117   # Jackett
      9091   # Transmission
      3000   # Grafana
    ];
  };
}