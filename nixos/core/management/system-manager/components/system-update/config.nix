{ config, lib, pkgs, systemConfig, getModuleConfig, moduleName, ... }:

let
  cfg = getModuleConfig moduleName;
in
{
  config = lib.mkIf (cfg.enable or true) {
    # System update implementation
    # Commands are defined in commands.nix
    # This will be populated from the extracted handler logic
  };
}
