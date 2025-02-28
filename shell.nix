# shell.nix
{ pkgs ? import <nixpkgs> {} }:

let
  inherit (pkgs) lib;
  packages = import ./shell/packages { inherit pkgs; };
  hooks = import ./shell/hooks { inherit pkgs; };
  scripts = import ./shell/scripts { inherit pkgs; };
  prebuild = import ./shell/prebuild { inherit pkgs lib; };
in

pkgs.mkShell {
  name = "NixOsControlCenter-InstallShell";
  inherit (packages) buildInputs;
  shellHook = ''
    ${hooks.shellHook}
    
    # Check if we have root rights
    if [[ $EUID -ne 0 ]]; then
      echo "Restarting shell with root privileges..."
      exec sudo "$(which nix-shell)" "$@"
    fi
    echo "Starting install script..."
    install
  '';
}
