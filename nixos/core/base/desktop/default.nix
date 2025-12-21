{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  cfg = getModuleConfig "desktop";
in {
  _module.metadata = {
    role = "core";
    name = "desktop";
    description = "Desktop environment configuration and management";
    category = "base";
    subcategory = "desktop";
    version = "1.0.0";
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