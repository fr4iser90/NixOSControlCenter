{ lib, pkgs, cfg, getModuleApi }:

# Script packages for optional enable flags (not a NixOS module)
{
  github = import ./github.nix { inherit lib pkgs cfg getModuleApi; };
  gitlab = import ./gitlab.nix { inherit lib pkgs cfg getModuleApi; };
  jira = import ./jira.nix { inherit lib pkgs cfg getModuleApi; };
}
