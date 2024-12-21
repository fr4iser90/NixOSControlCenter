{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.virtualisation.management;
in {
  imports = [
#    ./lib
#    ./core
#    ./machines
#    ./testing
    ./testing/nixos-vm.nix
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
  };
}