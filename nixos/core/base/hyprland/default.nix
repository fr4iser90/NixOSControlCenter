{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getCurrentModuleMetadata, ... }:

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "Hyprland compositor, Hall of Fame rice catalog, and wallpaper picker";
    category = "base";
    subcategory = "hyprland";
    version = "1.1.0";
  };

  imports = [
    ./options.nix
    (import ./config.nix { inherit config lib pkgs getModuleConfig moduleName; })
    ./commands.nix
  ];
}
