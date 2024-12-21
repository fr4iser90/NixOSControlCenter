{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.virtualisation.management;
  cliTools = import ../cli-management/lib/tools.nix { 
    inherit lib pkgs; 
    cliConfig = config.cli-management; 
  };
in {
  imports = [
    (import ./testing/nixos-vm.nix { inherit config lib pkgs cliTools; })
  ];

  options.virtualisation.management = {
    enable = mkEnableOption "Virtualization Management";
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.management.storage.enable;
        message = "Storage management must be enabled for virtualization management";
      }
    ];
    cli-management.enable = true;
    cli-management.enabledCategories = [ "vm" ];
  };
}