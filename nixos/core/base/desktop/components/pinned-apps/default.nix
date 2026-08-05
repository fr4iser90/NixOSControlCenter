{ config, lib, pkgs, getModuleConfig, ... }:

let
  cfg = getModuleConfig "desktop";
  env = cfg.environment or "plasma";
  enabled = (cfg.enable or true) && (
    (cfg.pinnedApps or []) != [] || (cfg.pinnedAppsAuto or true)
  );
in
{
  imports = lib.optionals enabled [
    (
      if env == "plasma" then ./plasma.nix
      else if env == "gnome" then ./gnome.nix
      else if env == "xfce" then ./xfce.nix
      else ./plasma.nix
    )
  ];
}
