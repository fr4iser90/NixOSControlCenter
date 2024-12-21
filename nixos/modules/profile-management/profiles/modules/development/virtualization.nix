# development/virtualization.nix
{ config, lib, pkgs, ... }:
{
    imports = [../../../../virtualization-management];

    # Aktiviere VM mit Remote-Zugriff
    virtualisation.management.testing.nixos-vm = {
      enable = true;
      memory = 8192;  # 8GB RAM
      cores = 4;      # 4 Kerne
      remote.enable = true;
    };
}