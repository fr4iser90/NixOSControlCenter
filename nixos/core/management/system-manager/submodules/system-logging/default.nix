{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  cfg = getModuleConfig "system-logging";
in
{
  imports = [
    ./options.nix
  ] ++ (lib.optionals (cfg.enable or true) [
    ./config.nix  # Import implementation logic
  ]);

}
