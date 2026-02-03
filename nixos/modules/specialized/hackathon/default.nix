{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

with lib;

let
  moduleName = baseNameOf ./. ;
  cfg = getModuleConfig moduleName;
  
  hackathonUsers = lib.filterAttrs
    (name: user: user.role == "hackathon-admin")
    (getModuleConfig "user");

  hasHackathonUsers = (lib.length (lib.attrNames hackathonUsers)) > 0;
  hackathonUser = if hasHackathonUsers then lib.head (lib.attrNames hackathonUsers) else "";

in {
  imports = if cfg.enable or false then
    [
      ./options.nix
    ] ++ (if hasHackathonUsers then [
      ./hackathon-fetch.nix
      ./hackathon-create.nix
      ./hackathon-update.nix
      ./hackathon-status.nix
      ./hackathon-cleanup.nix
    ] else [])
  else [];

  # Removed: Redundant enable setting (already defined in options.nix)
}
