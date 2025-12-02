{ config, lib, pkgs, ... }:

{
  programs.command-not-found.enable = false;

  environment.interactiveShellInit = ''
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
}
