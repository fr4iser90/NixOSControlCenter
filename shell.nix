# shell.nix — install bootstrap via install-wizard/scripts (Store bins, no repo .sh)
{ pkgs ? import <nixpkgs> {} }:

let
  lib = pkgs.lib;
  # Discovery helpers (same shape as flake specialArgs) so config-facade can resolve system-manager
  helpers = import ./nixos/core/management/module-manager/lib/module-config.nix {
    inherit lib;
    systemConfig = { };
  };
  installer = import ./nixos/core/management/install-wizard/scripts {
    inherit pkgs;
    inherit (helpers) getModuleApi getModuleMetadata;
  };
in

pkgs.mkShell {
  name = "NixOSControlCenter-InstallShell";
  buildInputs = installer.buildInputs;
  shellHook = ''
    ${installer.shellHook}

    if [[ $EUID -ne 0 ]]; then
      echo "Restarting shell with root privileges..."
      exec sudo -E env "PATH=$PATH" \
        "NCC_DRY_RUN=''${NCC_DRY_RUN-}" \
        "NCC_INSTALL_UI=''${NCC_INSTALL_UI-}" \
        "NCC_INSTALL_SHELL_ONLY=''${NCC_INSTALL_SHELL_ONLY-}" \
        "$(which nix-shell)" "$(pwd)/shell.nix"
    fi

    if [[ "''${NCC_INSTALL_SHELL_ONLY:-0}" == "1" ]]; then
      echo "Install shell ready (no auto-start). Try: install-dry | install-gui | install-fzf | install"
    elif [[ "''${NCC_DRY_RUN:-0}" == "1" ]] || [[ "''${NCC_DRY_RUN:-}" == "true" ]]; then
      echo "Starting install dry-run..."
      install-dry
    else
      echo "Starting install script..."
      install
    fi
  '';
}
