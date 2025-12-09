{ config, lib, pkgs, systemConfig, ... }:
{
  imports = [
    ./options.nix
  ] ++ (lib.optionals (systemConfig.management.logging.enable or true) [
    ./config.nix  # Import implementation logic
  ]);
}
