{ config, lib, pkgs, ... }:

let
  cliLib = import ../../lib { inherit lib pkgs; };
in {
  config = mkIf config.cli-management.enable {
    environment.systemPackages = [
      (cliLib.tools.mkCommand {
        category = "vm";
        name = "test-nixos";
        # ...
      })
    ];
  };
}