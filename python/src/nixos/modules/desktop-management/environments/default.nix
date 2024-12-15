# environments/default.nix
{ config, lib, pkgs, systemConfig, ... }:
{
  imports = [
    (./. + "/${systemConfig.desktop}")  # Lädt automatisch das richtige Desktop Environment
  ];
}