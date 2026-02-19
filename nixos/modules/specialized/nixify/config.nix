{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, nixifyModuleName, ... }:

with lib;

let
  # moduleName aus _module.args - NUR EINMAL berechnet in default.nix!
  moduleName = nixifyModuleName;
  cfg = getModuleConfig moduleName;
  moduleManager = getModuleApi "module-manager";
  systemManager = getModuleApi "system-manager";
  
  # Snapshot scripts
  snapshotScripts = {
    windows = pkgs.writeScriptBin "nixify-scan" ''
      #!${pkgs.powershell}/bin/pwsh
      # Windows Snapshot Script
      # This script will be replaced with the actual PowerShell script
      Write-Host "Nixify Windows Snapshot Script"
      Write-Host "This is a placeholder - actual script will be implemented"
    '';
    
    macos = pkgs.writeScriptBin "nixify-scan" ''
      #!${pkgs.bash}/bin/bash
      # macOS Snapshot Script
      # This script will be replaced with the actual shell script
      echo "Nixify macOS Snapshot Script"
      echo "This is a placeholder - actual script will be implemented"
    '';
    
    linux = pkgs.writeScriptBin "nixify-scan" ''
      #!${pkgs.bash}/bin/bash
      # Linux Snapshot Script
      # This script will be replaced with the actual shell script
      echo "Nixify Linux Snapshot Script"
      echo "This is a placeholder - actual script will be implemented"
    '';
  };
  
  # Web service (placeholder - will be implemented later)
  webService = pkgs.writeScriptBin "nixify-service" ''
    #!${pkgs.bash}/bin/bash
    # Nixify Web Service
    # This is a placeholder - actual Go service will be implemented
    echo "Nixify Web Service"
    echo "This is a placeholder - actual service will be implemented"
    echo "Port: ${toString cfg.webService.port}"
    echo "Host: ${cfg.webService.host}"
  '';
in
{
  config = lib.mkIf cfg.enable {
    # Web-Service als systemd-Service
    systemd.services.nixify-service = lib.mkIf cfg.webService.enable {
      enable = true;
      description = "Nixify Web Service";
      documentation = [ "https://github.com/fr4iser90/NixOSControlCenter" ];
      
      after = [ "network.target" ];
      wants = [ "network.target" ];
      
      serviceConfig = {
        Type = "simple";
        ExecStart = "${webService}/bin/nixify-service";
        Restart = "on-failure";
        RestartSec = 10;
        
        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        
        # Allow write access to ISO output directory if enabled
        ReadWritePaths = lib.optionals cfg.isoBuilder.enable [ cfg.isoBuilder.outputDir ];
      };
      
      environment = {
        PORT = toString cfg.webService.port;
        HOST = cfg.webService.host;
        MAPPING_DB_PATH = toString cfg.mapping.databasePath;
      };
      
      wantedBy = lib.mkIf cfg.webService.autoStart [ "multi-user.target" ];
    };
    
    # Snapshot-Scripts bereitstellen
    environment.systemPackages = lib.mkIf cfg.snapshot.enable [
      snapshotScripts.windows
      snapshotScripts.macos
      snapshotScripts.linux
    ];
    
    # Create ISO output directory if enabled
    systemd.tmpfiles.rules = lib.mkIf cfg.isoBuilder.enable [
      "d ${cfg.isoBuilder.outputDir} 0755 root root -"
    ];
  };
}
