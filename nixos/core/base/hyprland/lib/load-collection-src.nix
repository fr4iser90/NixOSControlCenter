# Resolve NCC-Hyperland-Collection source (catalog metadata only).
# Prefer local sibling checkout for development; else pinned GitHub fetch.
{ pkgs }:
let
  pin = import ./collection-pin.nix;
  # NixOSControlCenter/nixos/core/base/hyprland/lib → ../../../../../../ = Documents/Git
  sibling = ../../../../../../NCC-Hyperland-Collection;
  siblingCatalog = sibling + "/nix/catalog.nix";
  useSibling = builtins.pathExists siblingCatalog;
in
  if useSibling then sibling
  else
    pkgs.fetchFromGitHub {
      inherit (pin) owner repo rev hash;
    }
