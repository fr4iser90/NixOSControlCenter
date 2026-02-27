{ config, lib, pkgs, sshClientCfg, getModuleApi, ... }:

let
  ui = getModuleApi "cli-formatter";
  cfg = sshClientCfg;
  previewScript = import ../scripts/ssh-connection-preview.nix {
    inherit pkgs;
    sshClientCfg = cfg;
  };

  sshClientManagerServerUtils = ''
    # SSH Client Manager Server Utilities
    # This module provides core functions for managing SSH server entries (NOT connections)
    
    # Path to user's credentials file where server entries are stored
    CREDS_FILE="/home/$USER/${cfg.credentialsFile}"

    # Load saved servers from credentials file
    # Returns the contents of the credentials file or creates a new one if it doesn't exist
    load_saved_servers() {
        if [[ -f "$CREDS_FILE" ]]; then
            cat "$CREDS_FILE"
        else
            ${ui.messages.info "Credentials file not found. Creating a new one."}
            mkdir -p "$(dirname "$CREDS_FILE")"
            touch "$CREDS_FILE"
            chmod 600 "$CREDS_FILE"
        fi
    }

    # Save a new server entry to credentials file
    # Parameters: server_ip, username
    save_new_server() {
        local server_ip="$1"
        local username="$2"
        echo "$server_ip=$username" >> "$CREDS_FILE"
        ${ui.messages.success "New server saved."}
    }

    # Get user input with prompt
    # Parameters: prompt text
    get_user_input() {
        local prompt="$1"
        echo -n "$prompt"
        read -r input
        echo "$input"
    }

    # Get password input (hidden) with prompt
    # Parameters: prompt text
    get_password_input() {
        local prompt="$1"
        echo -n "$prompt " >&2
        read -rs input
        echo ""  # Add a newline after input for clarity
        echo "$input"
    }
    
    # Interactive server selection using fzf (fuzzy finder)
    # Parameters: servers_list
    # Returns: selected server and action
    select_server() {
        local servers_list="$1"
        local selection action
        
        # Create the list of options directly in the pipe
        selection=$( (echo "Add new server"; while IFS='=' read -r ip user; do 
            if [[ -n "$ip" && -n "$user" ]]; then
                echo "$ip ($user)"
            fi
        done <<< "$servers_list") | ${pkgs.fzf}/bin/fzf \
            --prompt="${cfg.fzf.theme.prompt}" \
            --pointer="${cfg.fzf.theme.pointer}" \
            --marker="${cfg.fzf.theme.marker}" \
            --header="Available SSH Servers" \
            --header-first \
            ${lib.optionalString (cfg.fzf.preview.enable or false) ''
              --preview "${previewScript}/bin/ssh-connection-preview {}" \
              --preview-window="${cfg.fzf.preview.position}"
            ''} \
            --expect=ctrl-x,ctrl-e,ctrl-n,enter 2>/dev/null)
        
        # Parse the selection and action
        local key=$(echo "$selection" | head -1)
        local choice=$(echo "$selection" | tail -1)
        
        # Map key to action
        case "$key" in
            "ctrl-x") action="delete" ;;
            "ctrl-e") action="edit" ;;
            "ctrl-n"|"") 
                if [[ "$choice" == "Add new server" ]]; then
                    action="new"
                else
                    action="connect"
                fi
                ;;
            *) action="connect" ;;
        esac
        
        # Output both the selection and action
        echo "$choice"
        echo "$action"
    }

    # Delete a server from the credentials file
    delete_server() {
        local servers_list="$(load_saved_servers)"
        local selected="$(select_server "$servers_list")"
        
        if [[ "$selected" == "Add new server" ]]; then
            return
        fi
        
        local server_ip=''${selected%% *}
        if [[ -n "$server_ip" ]]; then
            ${ui.messages.loading "Deleting server..."}
            sed -i "/^$server_ip=/d" "$CREDS_FILE"
            ${ui.messages.success "Server deleted successfully."}
        fi
    }
  '';
in {
  sshClientManagerServerUtils = sshClientManagerServerUtils;
}
