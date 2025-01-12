# install-shell.nix
{ pkgs ? import <nixpkgs> {} }:

let
  inherit (pkgs) lib;
  packages = import ./app/shell/install/packages { inherit pkgs; };
  hooks = import ./app/shell/install/hooks { inherit pkgs; };
  scripts = import ./app/shell/install/scripts { inherit pkgs; };
  prebuild = import ./app/shell/install/prebuild { inherit pkgs lib; }; 
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
  '';
}