{ config, lib, pkgs, systemConfig, ... }:

{
  imports = [
    ./servicenow.nix
    ./salesforce.nix
  ];
}
