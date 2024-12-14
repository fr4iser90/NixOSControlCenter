{ pkgs ? import <nixpkgs> {} }:

let
  packages = import ./shell/packages { inherit pkgs; };
  hooks = import ./shell/hooks { inherit pkgs; };
in

pkgs.mkShell {
  name = "NixOsControlCenterEnv";
  inherit (packages) buildInputs;
  
  noNewPrivileges = false;
  PKG_CONFIG_PATH = "${pkgs.pkg-config}/bin";

  shellHook = hooks.shellHook;
}
