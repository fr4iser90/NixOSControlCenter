{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.module-management.module-manager or {};
in {
  imports = [
    ./options.nix
  ] ++ (if (cfg.enable or true) then [
    ./config.nix
    ./commands.nix
    ./handlers/feature-manager.nix
    ./handlers/module-version-check.nix
  ] else [
    ./config.nix
  ]);
}

