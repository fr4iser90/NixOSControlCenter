{ config, lib, pkgs, ... }:

let
  currentDir = toString ./.;
  # Load all .nix files in current directory
  nixFiles = builtins.attrNames (lib.filterAttrs 
    (_: v: lib.hasSuffix ".nix" v) 
    (builtins.readDir currentDir));
  
  # Create full import paths
  imports = map (file: currentDir + "/${file}") nixFiles;
in
{
  imports = if nixFiles == [] then [] else imports;
}
