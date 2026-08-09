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
      # Keep NCC_* so dry-run / shell-only survive the sudo re-exec.
      exec sudo -E env "PATH=$PATH" \
        "NCC_DRY_RUN=''${NCC_DRY_RUN-}" \
        "NCC_INSTALL_UI=''${NCC_INSTALL_UI-}" \
        "NCC_INSTALL_SHELL_ONLY=''${NCC_INSTALL_SHELL_ONLY-}" \
        "$(which nix-shell)" "$(pwd)/shell.nix"
    fi

    # Auto-start policy (set on the host before nix-shell):
    #   NCC_INSTALL_SHELL_ONLY=1  → interactive shell only (then: install-dry / install-gui / …)
    #   NCC_DRY_RUN=1             → install-dry
    #   (default)                 → install
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
