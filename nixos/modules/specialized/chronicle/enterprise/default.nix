{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    ./multi-tenancy.nix
    ./sso.nix
    ./kubernetes.nix
  ];
}
