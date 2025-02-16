{ config, lib, pkgs, ... }:

let
  ui = config.features.terminal-ui.api;
  cfg = config.services.ssh-client-manager;

  sshClientManagerServerUtils = ''
    CREDS_FILE="/home/$USER/${cfg.credentialsFile}"

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

    save_new_server() {
        local server_ip="$1"
        local username="$2"
        echo "$server_ip=$username" >> "$CREDS_FILE"
        ${ui.messages.success "New server saved."}
    }

    get_user_input() {
        local prompt="$1"
        echo -n "$prompt"
        read -r input
        echo "$input"
    }

    connect_to_server() {
        local full_server="$1"
        local test_only="''${2:-false}"
        
        if [[ "$test_only" == "true" ]]; then
            ${pkgs.openssh}/bin/ssh -o BatchMode=yes -o ConnectTimeout=5 "$full_server" exit 2>/dev/null
            return $?
        fi
        
        ${pkgs.openssh}/bin/ssh "$full_server"
    }

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
            ${lib.optionalString cfg.fzf.preview.enable ''
              --preview "${config.services.ssh-client-manager.connectionPreviewScript}/bin/ssh-connection-preview {}" \
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
  config = {
    services.ssh-client-manager = {
      sshClientManagerServerUtils = sshClientManagerServerUtils;
    };
  };
}