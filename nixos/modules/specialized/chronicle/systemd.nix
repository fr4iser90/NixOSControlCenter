{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.modules.specialized.chronicle;
in
{
  config = lib.mkMerge [
    # Recording service
    (lib.mkIf (cfg.enable && (cfg.service.enableDaemon or false)) {
      systemd.user.services."chronicle" = {
        description = "Chronicle Service";
        
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.writeShellScript "chronicle-service" ''
            exec chronicle start
          ''}";
          Restart = "on-failure";
          RestartSec = 5;
        };
        
        # Auto-start if configured
        wantedBy = lib.mkIf (cfg.service.autoStart or false) [ "default.target" ];
      };
    })

    # API service (v2.0.0)
    (lib.mkIf (cfg.enable && (cfg.api.enable or false) && (cfg.api.autoStart or false)) {
      systemd.user.services."chronicle-api" = {
        description = "Chronicle REST API Server";
        documentation = [ "https://github.com/fr4iser90/NixOSControlCenter" ];
        
        after = [ "network.target" ];
        wants = [ "network.target" ];
        
        serviceConfig = {
          Type = "simple";
          ExecStart = "${pkgs.writeShellScript "chronicle-api-service" ''
            #!/usr/bin/env bash
            export CHRONICLE_API_HOST="${cfg.api.host or "localhost"}"
            export CHRONICLE_API_PORT="${toString (cfg.api.port or 8080)}"
            export CHRONICLE_DATA_DIR="${cfg.outputDir}"
            exec chronicle-api
          ''}";
          Restart = "on-failure";
          RestartSec = 10;
          
          # Security hardening
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = "read-only";
          
          # Allow write access to output directory
          ReadWritePaths = [ cfg.outputDir ];
        };
        
        wantedBy = [ "default.target" ];
      };
    })
  ];
}
