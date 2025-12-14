{ config, lib, pkgs, systemConfig, ... }:
{
  imports = [
    ./options.nix
  ] ++ (lib.optionals (systemConfig.core.management.system-manager.submodules.system-logging.enable or true) [
    ./config.nix  # Import implementation logic
  ]);
}
