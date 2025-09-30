{ config, lib, pkgs, ... }:

{
  # Standard nix-command-not-found deaktivieren
  programs.command-not-found.enable = false;

  # Unser globales Fallback-Skript
  environment.etc."nix_command_not_found".text = ''
    run_in_project_shell() {
        local cmd="$1"
        shift
        if [ -f ./flake.nix ]; then
            echo ">>> running '$cmd $*' inside project flake.nix"
            nix develop . -c "$cmd" "$@"
            return $?
        elif [ -f ./shell.nix ]; then
            echo ">>> running '$cmd $*' inside project shell.nix"
            nix-shell --run "$cmd $*"
            return $?
        fi
        return 127
    }

    # Bash handler
    command_not_found_handle() {
        run_in_project_shell "$@" || {
            echo "Command '$1' not found and no shell.nix/flake.nix in this directory."
            return 127
        }
    }

    # Zsh handler
    command_not_found_handler() {
        run_in_project_shell "$@" || {
            echo "zsh: command not found: $1 (no shell.nix/flake.nix here)"
            return 127
        }
    }
  '';

  environment.interactiveShellInit = ''
    source /etc/nix_command_not_found
  '';
}
