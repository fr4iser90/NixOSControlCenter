# This file contains the default configuration for the CLI management system.
{ lib, pkgs }:

{
  tools = import ./tools.nix { inherit lib pkgs; };
  types = import ./types.nix { inherit lib; };
}