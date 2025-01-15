{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.pihole;
  containerVars = import ./vars.nix { inherit lib config; };
  piholeConfig = import ./pihole.nix { inherit lib pkgs config containerVars; };
in {
  imports = [
    ./config.nix
    ./container.nix
    ./vars.nix
  ];

  services.pihole = {
    enable = true;
    subdomain = "pihole";
    domain = "example.com";
  };
}
