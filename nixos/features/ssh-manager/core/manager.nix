{ config, lib, pkgs, ... }:

let
  ui = config.features.terminal-ui.api;
  serverUtils = ''
    CREDS_FILE="$HOME/.creds"

    load_saved_servers() {
        if [[ -f "$CREDS_FILE" ]]; then
            cat "$CREDS_FILE"
        else
            ${ui.messages.info "Credentials file not found. Creating a new one."}
            touch "$CREDS_FILE"
        fi
    }

    save_new_server() {
        local server_ip="$1"
        local username="$2"
        echo "$server_ip=$username" >> "$CREDS_FILE"
        ${ui.messages.success "New server saved."}
    }

    get_user_input() {
        local prompt="$1"
        ${ui.prompts.prompt "$prompt"}
        read -r input
        echo "$input"
    }

    select_server() {
        local servers_list="$1"
        local options=("Add new server")
        while IFS='=' read -r ip user; do
            if [[ -n "$ip" && -n "$user" ]]; then  # Prüfe auf nicht-leere Werte
                options+=("$ip ($user)")
            fi
        done <<< "$servers_list"
        
        # Verwende printf um die Optionen an fzf zu übergeben
        printf '%s\n' "''${options[@]}" | ${pkgs.fzf}/bin/fzf \
            --prompt="Select a server: " \
            --header="Available servers"
    }
  '';
in {
  options = {
    services.ssh-manager.utils = lib.mkOption {
      type = lib.types.str;
      default = serverUtils;
      description = "SSH Manager utility functions";
    };
  };

  config = {};
}
