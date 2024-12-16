# install-shell.nix
{ pkgs ? import <nixpkgs> {} }:

let
  packages = import ./app/shell/install/packages { inherit pkgs; };
  hooks = import ./app/shell/install/hooks { inherit pkgs; };
  scripts = import ./app/shell/install/scripts { inherit pkgs; };
in

pkgs.mkShell {
  name = "NixOsControlCenter-InstallShell";
  inherit (packages) buildInputs;  
  shellHook = hooks.shellHook;
}