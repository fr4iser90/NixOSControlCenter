{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.virtualisation.management.storage;
in {
  options.virtualisation.management.storage = {
    enable = mkEnableOption "Storage Management";
    
    basePath = mkOption {
      type = types.path;
      default = "/var/lib/virt/images";
      description = "Base path for VM images";
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.basePath} 0775 root libvirt -"
    ];
  };
}