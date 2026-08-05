# shell.nix
{ pkgs ? import <nixpkgs> {} }:

let
  packages = import ./shell/packages { inherit pkgs; };
  hooks = import ./shell/hooks { inherit pkgs; };
in

pkgs.mkShell {
  name = "NixOSControlCenter-InstallShell";
  inherit (packages) buildInputs;
  shellHook = ''
    ${hooks.shellHook}
    
    # Check if we have root rights
    if [[ $EUID -ne 0 ]]; then
      echo "Restarting shell with root privileges..."
      # Preserve current directory and pass shell.nix path explicitly
      exec sudo -E env "PATH=$PATH" "$(which nix-shell)" "$(pwd)/shell.nix"
    fi
    echo "Starting install script..."
    install
  '';
}
