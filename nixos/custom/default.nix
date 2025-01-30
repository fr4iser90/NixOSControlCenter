{ config, lib, pkgs, ... }:

let
  currentDir = toString ./.;
  # Load all .nix files in current directory except default.nix
  nixFiles = builtins.filter
    (name: name != "default.nix" && lib.hasSuffix ".nix" name)
    (builtins.attrNames (builtins.readDir currentDir));
  
  # Create import paths relative to current directory
  imports = map (file: ./. + "/${file}") nixFiles;
in
{
  imports = imports;
}
