{ config, lib, getModuleConfig, moduleName, ... }:
let
  cfg = getModuleConfig moduleName;
in
{
  config = lib.mkIf (cfg.enable or false) {
    # Network configuration will be handled in default.nix
  };
}
