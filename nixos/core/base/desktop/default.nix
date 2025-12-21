{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  cfg = getModuleConfig "desktop";
in {
  _module.metadata = {
    role = "internal";
    name = "desktop";
    description = "Desktop environment configuration and management";
    category = "base";
    subcategory = "desktop";
    stability = "stable";
  };

  imports = if cfg.enable or false then [
    ./options.nix
    ./display-managers
    ./display-servers
    ./environments
    ./themes
    ./config.nix
  ] else [];
}