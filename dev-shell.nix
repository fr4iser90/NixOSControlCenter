# dev-shell.nix
{ pkgs ? import <nixpkgs> {} }:

let
  packages = import ./app/shell/dev/packages { inherit pkgs; };
  hooks = import ./app/shell/dev/hooks { inherit pkgs; };
in

pkgs.mkShell {
  name = "NixOsControlCenter-DevShell";
  inherit (packages) buildInputs;
  
  noNewPrivileges = false;
  PKG_CONFIG_PATH = "${pkgs.pkg-config}/bin";

  shellHook = hooks.shellHook;
}