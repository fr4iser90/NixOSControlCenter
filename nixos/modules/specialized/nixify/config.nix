{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, nixifyModuleName, buildGoApplication ? null, gomod2nix ? null, ... }:

with lib;

let
  # moduleName aus _module.args - NUR EINMAL berechnet in default.nix!
  moduleName = nixifyModuleName;
  cfg = getModuleConfig moduleName;
  # Note: getModuleApi calls removed - not currently used in config.nix
  # They can be added back when needed for config generation
  
  # Snapshot scripts - actual implementations
  snapshotScripts = {
    windows = pkgs.writeScriptBin "nixify-scan" (builtins.readFile ./snapshot/windows/nixify-scan.ps1);
    
    macos = pkgs.writeScriptBin "nixify-scan" ''
      #!${pkgs.bash}/bin/bash
      ${builtins.readFile ./snapshot/macos/nixify-scan.sh}
    '';
    
    linux = pkgs.writeScriptBin "nixify-scan" ''
      #!${pkgs.bash}/bin/bash
      ${builtins.readFile ./snapshot/linux/nixify-scan.sh}
    '';
  };
  
  # Web service - Go REST API
  webService = if buildGoApplication != null && gomod2nix != null then
    (buildGoApplication {
      pname = "nixify-service";
      version = "0.1.0";
      src = ./web-service/api;
      go = pkgs.go;
      modules = ./web-service/api/gomod2nix.toml;
      subPackages = [ "." ];  # Wie in tui-engine/package.nix
    })
  else
    # Fallback: Simple wrapper script if buildGoApplication not available
    pkgs.writeScriptBin "nixify-service" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      
      PORT="''${PORT:-${toString (cfg.webService.port or 8080)}}"
      HOST="''${HOST:-${cfg.webService.host or "127.0.0.1"}}"
      DATA_DIR="''${DATA_DIR:-/var/lib/nixify}"
      MAPPING_DB_PATH="''${MAPPING_DB_PATH:-${toString (cfg.mapping.databasePath or ./web-service/api/static/data/mapping-database.json)}}"
      
      echo "Nixify Web Service (Placeholder)"
      echo "Port: $PORT"
      echo "Host: $HOST"
      echo "Data Dir: $DATA_DIR"
      echo ""
      echo "Note: Full Go service will be available when buildGoApplication is configured"
      echo "The Go service code is ready in: web-service/api/"
      echo ""
      echo "Service would listen on: http://$HOST:$PORT"
      
      # Keep script running (for systemd)
      while true; do
        sleep 3600
      done
    '';
in
{
  config = lib.mkIf cfg.enable {
    # Web-Service als systemd-Service
    systemd.services.nixify-service = lib.mkIf (cfg.webService.enable or false) {
      enable = true;
      description = "Nixify Web Service";
      documentation = [ "https://github.com/fr4iser90/NixOSControlCenter" ];
      
      after = [ "network.target" ];
      wants = [ "network.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${webService}/bin/nixify-web-service";
        Restart = "on-failure";
        RestartSec = 10;
        
        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        
        # Allow write access to ISO output directory if enabled
        ReadWritePaths = lib.optionals (cfg.isoBuilder.enable or false) [ (cfg.isoBuilder.outputDir or "/var/lib/nixify/isos") ];
      };
      
      environment = {
        PORT = toString (cfg.webService.port or 8080);
        HOST = (cfg.webService.host or "127.0.0.1");
        DATA_DIR = "/var/lib/nixify";
        MAPPING_DB_PATH = toString (cfg.mapping.databasePath or ./web-service/api/static/data/mapping-database.json);
        SHOW_STATUS_BADGE = if (cfg.webService.showStatusBadge or true) then "true" else "false";
      };
      
      wantedBy = lib.mkIf (cfg.webService.autoStart or false) [ "multi-user.target" ];
    };
    
    # Snapshot-Scripts bereitstellen
    environment.systemPackages = lib.mkIf (cfg.snapshot.enable or true) [
      snapshotScripts.windows
      snapshotScripts.macos
      snapshotScripts.linux
    ];
    
    # Create data directories
    systemd.tmpfiles.rules = [
      "d /var/lib/nixify 0755 root root -"
    ] ++ lib.optionals (cfg.isoBuilder.enable or false) [
      "d ${cfg.isoBuilder.outputDir or "/var/lib/nixify/isos"} 0755 root root -"
    ];
  };
}
