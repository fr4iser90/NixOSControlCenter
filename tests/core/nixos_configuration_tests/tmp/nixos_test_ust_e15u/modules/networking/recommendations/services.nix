# modules/networking/recommendations/services.nix
{
  # Basis-Services
  bitwarden = {
    ports = {
      tcp = [ ];
      udp = [ 34197 ];
    };
    recommended = "local";
    reason = "Contains sensitive password data";
  };
  
  portainer = {
    ports = {
      tcp = [ 9000 ];
      udp = [ ];
    };
    recommended = "local";
    reason = "Administrative interface for Docker";
  };
  
  ssh = {
    ports = {
      tcp = [ 22 ];
      udp = [ ];
    };
    recommended = "local";
    reason = "System administration access";
  };
  
  nginx = {
    ports = {
      tcp = [ 80 443 ];
      udp = [ ];
    };
    recommended = "public";
    reason = "Web server/reverse proxy";
  };

  # Media Services
  plex = {
    ports = {
      tcp = [ 32400 3005 8324 32469 ];
      udp = [ 1900 5353 32410 32412 32413 32414 ];
    };
    recommended = "local";
    reason = "Media server, use reverse proxy for external access";
  };

  jellyfin = {
    ports = {
      tcp = [ 8096 8920 ];  # 8096 HTTP, 8920 HTTPS
      udp = [ 1900 7359 ];  # DLNA discovery
    };
    recommended = "local";
    reason = "Media server, use reverse proxy for external access";
  };

  emby = {
    ports = {
      tcp = [ 8096 8920 ];
      udp = [ 7359 ];
    };
    recommended = "local";
    reason = "Media server, use reverse proxy for external access";
  };

  # Network Services
  pihole = {
    ports = {
      tcp = [ 53 80 ];
      udp = [ 53 67 ];  # DNS and DHCP
    };
    recommended = "local";
    reason = "DNS and ad-blocking service, security critical";
  };

  adguard = {
    ports = {
      tcp = [ 53 80 443 3000 ];
      udp = [ 53 ];
    };
    recommended = "local";
    reason = "DNS and ad-blocking service, security critical";
  };

  # Monitoring
  grafana = {
    ports = {
      tcp = [ 3000 ];
      udp = [ ];
    };
    recommended = "local";
    reason = "Monitoring interface, contains sensitive data";
  };

  prometheus = {
    ports = {
      tcp = [ 9090 ];
      udp = [ ];
    };
    recommended = "local";
    reason = "Monitoring data collection, internal service";
  };

  # Download Services
  transmission = {
    ports = {
      tcp = [ 9091 51413 ];
      udp = [ 51413 ];
    };
    recommended = "local";
    reason = "Torrent client, use reverse proxy for WebUI";
  };

  qbittorrent = {
    ports = {
      tcp = [ 8080 6881 ];
      udp = [ 6881 ];
    };
    recommended = "local";
    reason = "Torrent client, use reverse proxy for WebUI";
  };

  # Home Automation
  homeassistant = {
    ports = {
      tcp = [ 8123 ];
      udp = [ 5353 ];
    };
    recommended = "local";
    reason = "Home automation platform, use reverse proxy for external access";
  };

  nodered = {
    ports = {
      tcp = [ 1880 ];
      udp = [ ];
    };
    recommended = "local";
    reason = "Automation tool, internal service";
  };

  # Development Tools
  gitea = {
    ports = {
      tcp = [ 3000 22 ];
      udp = [ ];
    };
    recommended = "local";
    reason = "Git service, use reverse proxy for external access";
  };

  # Backup Services
  duplicati = {
    ports = {
      tcp = [ 8200 ];
      udp = [ ];
    };
    recommended = "local";
    reason = "Backup service interface, contains sensitive data";
  };

  # Database Management
  adminer = {
    ports = {
      tcp = [ 8080 ];
      udp = [ ];
    };
    recommended = "local";
    reason = "Database management interface, security critical";
  };

  # File Sharing
  nextcloud = {
    ports = {
      tcp = [ 80 443 ];
      udp = [ ];
    };
    recommended = "local";
    reason = "File sharing platform, use reverse proxy for external access";
  };

  syncthing = {
    ports = {
      tcp = [ 8384 22000 ];
      udp = [ 22000 21027 ];
    };
    recommended = "local";
    reason = "File synchronization service, use reverse proxy for WebUI";
  };
}