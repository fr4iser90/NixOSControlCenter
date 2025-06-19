{ config, lib, pkgs, ... }:

let
  ui = config.features.terminal-ui.api;
  cfg = config.services.ssh-client-manager;

  sshClientManagerServerUtils = ''
    # SSH Client Manager Server Utilities
    # This module provides core functions for managing SSH server connections
    
    # Path to user's credentials file where server entries are stored
    CREDS_FILE="/home/$USER/${cfg.credentialsFile}"
    # Temporary password storage (in memory only) - used to avoid multiple password prompts
    TEMP_PASSWORD=""

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
        echo -n "$prompt"
        read -rs input
        echo "$input"
    }

    # Connect to SSH server with various authentication methods
    # Parameters:
    #   $1: full_server (user@host)
    #   $2: test_only (true/false) - if true, only test connection, don't establish session
    #   $3: use_password (true/false) - if true, use cached password with sshpass
    connect_to_server() {
        local full_server="$1"
        local test_only="''${2:-false}"
        local use_password="''${3:-false}"
        local status=0
        
        if [[ "$test_only" == "true" ]]; then
            if [[ "$use_password" == "true" && -n "$TEMP_PASSWORD" ]]; then
                # Use password authentication with sshpass for test connection
                # Create temporary password file for sshpass (more reliable than -p flag)
                local temp_pass_file=$(mktemp)
                echo "$TEMP_PASSWORD" > "$temp_pass_file"
                ${pkgs.sshpass}/bin/sshpass -f "$temp_pass_file" ${pkgs.openssh}/bin/ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$full_server" exit 2>&1 | tee /tmp/ssh-test.log
                status=$?
                rm -f "$temp_pass_file"
            else
                # Use key-based authentication for test connection
                ${pkgs.openssh}/bin/ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "$full_server" exit 2>&1 | tee /tmp/ssh-test.log
                status=$?
            fi
            return $status
        fi
        
        # Full connection (not test mode)
        if [[ "$use_password" == "true" && -n "$TEMP_PASSWORD" ]]; then
            # Use password authentication with sshpass for full connection
            local temp_pass_file=$(mktemp)
            echo "$TEMP_PASSWORD" > "$temp_pass_file"
            ${pkgs.sshpass}/bin/sshpass -f "$temp_pass_file" ${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=no "$full_server"
            local result=$?
            rm -f "$temp_pass_file"
            return $result
        else
            # Use key-based authentication for full connection
            ${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=no "$full_server"
        fi
    }
    
    # Share SSH key to remote server using cached password
    # Parameters: username, server
    share_ssh_key() {
        local username="$1"
        local server="$2"
        
        if [[ -n "$TEMP_PASSWORD" ]]; then
            # Use the cached password with sshpass for key sharing
            ${ui.messages.info "Copying SSH key to the remote server..."}
            ${pkgs.sshpass}/bin/sshpass -p "$TEMP_PASSWORD" ${pkgs.openssh}/bin/ssh-copy-id -i "$HOME/.ssh/id_rsa.pub" "$username@$server"
            return $?
        else
            # Fall back to standard method (will prompt for password)
            ${pkgs.openssh}/bin/ssh-copy-id -i "$HOME/.ssh/id_rsa.pub" "$username@$server"
            return $?
        fi
    }
    
    # Clear the temporary password from memory for security
    clear_temp_password() {
        TEMP_PASSWORD=""
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
  config = {
    services.ssh-client-manager = {
      sshClientManagerServerUtils = sshClientManagerServerUtils;
    };
    environment.systemPackages = [
      pkgs.sshpass  # Add sshpass as a dependency for password automation
    ];
  };
}
