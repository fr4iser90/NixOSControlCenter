{ pkgs ? import <nixpkgs> {} }:

let
  packages = import ./app/shell/packages { inherit pkgs; };
  hooks = import ./app/shell/hooks { inherit pkgs; };
in

pkgs.mkShell {
  name = "NixOsControlCenterEnv";
  inherit (packages) buildInputs;
  
  noNewPrivileges = false;
  PKG_CONFIG_PATH = "${pkgs.pkg-config}/bin";

  shellHook = hooks.shellHook;
}
