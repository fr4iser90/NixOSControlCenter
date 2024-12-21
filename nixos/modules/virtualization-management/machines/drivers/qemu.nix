{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.virtualisation.management.machines;
in {
  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      qemu
      virt-manager
      spice-gtk
      win-virtio
      OVMF
    ];
  };
}