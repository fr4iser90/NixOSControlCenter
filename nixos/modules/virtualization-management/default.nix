{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.virtualisation.management;
in {
  imports = [
    (import ./testing/nixos-vm.nix { inherit config lib pkgs; })
  ];

  options.virtualisation.management = {
    enable = mkEnableOption "Virtualization Management";
    storage.enable = mkEnableOption "Storage Management for Virtualization";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.management.storage.enable;
        message = "Storage management must be enabled for virtualization management";
      }
      {
        assertion = config.cli-management.enable;
        message = "CLI management must be enabled for virtualization management";
      }
    ];
    
    # Aktiviere die notwendigen Komponenten
    virtualisation.management.storage.enable = true;

    # Registriere VM-Kategorie
    cli-management.categories.vm = "Virtual Machine Management";
  };
}