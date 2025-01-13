{ config, lib, pkgs, ... }:

{
  imports = [
    ./networking.nix
    ./storage.nix
    ./security.nix
    ./monitoring.nix
    ./types.nix
  ];

  options.containerManager = {
    enable = lib.mkEnableOption "Container management";
    
    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/containers";
      description = "Base directory for container data";
    };
  };

  config = lib.mkIf config.containerManager.enable {
    # Basis-Setup
    systemd.services.container-init = {
      description = "Initialize container directory structure";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeScript "init-containers" ''
          #!${pkgs.bash}/bin/bash
          mkdir -p ${config.containerManager.dataDir}
          chmod 755 ${config.containerManager.dataDir}
        '';
      };
    };

    # Aktiviere Podman
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
    };

    # Stelle sicher, dass Podman vor den Container-Services startet
    systemd.services.container-init.after = [ "podman.service" ];
  };
}