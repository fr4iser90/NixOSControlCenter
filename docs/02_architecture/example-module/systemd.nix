{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = systemConfig.modules.example-module or {};
in
  mkIf (cfg.enable or false) {
    # Example systemd service
    # systemd.services.example-service = {
    #   description = "Example service";
    #   wantedBy = [ "multi-user.target" ];
    #   serviceConfig = {
    #     ExecStart = "${pkgs.example-package}/bin/example";
    #     Restart = "always";
    #   };
    # };

    # Example systemd timer
    # systemd.timers.example-timer = {
    #   wantedBy = [ "timers.target" ];
    #   timerConfig = {
    #     OnCalendar = "daily";
    #   };
    # };
  }

