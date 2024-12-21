{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.virtualisation.management.machines;
in {
  imports = [ ./drivers/qemu.nix ];
  
  options.virtualisation.management.machines = {
    enable = mkEnableOption "VM Management";
  };

  config = mkIf cfg.enable {
    virtualisation = {
      libvirtd.enable = true;
      spiceUSBRedirection.enable = true;
    };
  };
}