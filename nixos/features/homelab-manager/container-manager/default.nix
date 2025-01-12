{ config, lib, pkgs, ... }:

{
  imports = [
    ./networking.nix
    ./storage.nix
    ./security.nix
    ./monitoring.nix
    ./types.nix
  ];

  options.homelab = {
    enable = lib.mkEnableOption "Homelab container management";
    
    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/homelab";
      description = "Base directory for homelab data";
    };
  };

  config = lib.mkIf config.homelab.enable {
    # Basis-Setup
    systemd.services.homelab-init = {
      description = "Initialize homelab directory structure";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeScript "init-homelab" ''
          #!${pkgs.bash}/bin/bash
          mkdir -p ${config.homelab.dataDir}
          chmod 755 ${config.homelab.dataDir}
        '';
      };
    };

    # Aktiviere Podman
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;  # Optional: Docker-Kompatibilitäts-Layer
    };
  };
}