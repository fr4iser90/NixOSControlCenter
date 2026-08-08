# PostgreSQL (and helpers) for server / homelab roles.
{ config, lib, pkgs, ... }:
{
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
  };

  environment.systemPackages = with pkgs; [
    postgresql_16
    pgcli
  ];
}
