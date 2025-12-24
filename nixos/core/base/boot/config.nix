{ config, lib, getModuleConfig, moduleName, ... }:
let
  cfg = getModuleConfig moduleName;
in
{
  config = lib.mkIf (cfg.enable or false) {
    # Boot configuration will be handled in default.nix
  };
}
