{ config, lib, pkgs, ... }:

let
  ui = config.features.terminal-ui.api;
  cfg = config.services.ssh-manager;
  
  connectScript = pkgs.writeScriptBin "ssh-manager" ''
    #!${pkgs.bash}/bin/bash
    
    # Trap for CTRL+C
    trap '${ui.messages.error "Operation cancelled"}; exit 0' INT
    
    ${cfg.utils}

    connect_to_server() {
        local full_server="$1"
        local test_only="''${2:-false}"
        
        if [[ "$test_only" == "true" ]]; then
            ${pkgs.openssh}/bin/ssh -o BatchMode=yes -o ConnectTimeout=5 "$full_server" exit 2>/dev/null
            return $?
        fi
        
        ${pkgs.openssh}/bin/ssh "$full_server"
    }

    add_ssh_key() {
        local username="$1"
        local server="$2"
        if [[ ! -f "$HOME/.ssh/id_rsa.pub" ]]; then
            ${ui.messages.info "SSH key not found. Generating a new SSH key."}
            ${pkgs.openssh}/bin/ssh-keygen -t ${toString cfg.keyType} -b ${toString cfg.keyBits} -f "$HOME/.ssh/id_rsa" -N ""
        fi
        ${pkgs.openssh}/bin/ssh-copy-id "$username@$server"
    }

    handle_action() {
        local selection="$1"
        local action="$2"
        
        if [[ -z "$selection" ]]; then
            ${ui.messages.error "No server selected"}
            return
        fi
        
        case "$action" in
            "connect")
                if [[ "$selection" == "Add new server" ]]; then
                    local server_ip="$(get_user_input "Enter server IP/hostname: ")"
                    local username="$(get_user_input "Enter username: ")"
                    if [[ -n "$server_ip" && -n "$username" ]]; then
                        save_new_server "$server_ip" "$username"
                        ${ui.messages.info "Testing connection..."}
                        if connect_to_server "$username@$server_ip" true; then
                            ${ui.messages.success "Connection successful!"}
                            add_ssh_key "$username" "$server_ip"
                        else
                            ${ui.messages.error "Could not connect to server. Please check credentials."}
                        fi
                    fi
                else
                    local server=''${selection%% *}
                    local user=''${selection#* (}
                    user=''${user%)*}
                    connect_to_server "$user@$server"
                fi
                ;;
            "delete")
                if [[ "$selection" != "Add new server" ]]; then
                    local server=''${selection%% *}
                    ${ui.messages.loading "Deleting server..."}
                    sed -i "/^$server=/d" "$CREDS_FILE"
                    ${ui.messages.success "Server deleted successfully."}
                fi
                ;;
            "edit")
                if [[ "$selection" != "Add new server" ]]; then
                    local server=''${selection%% *}
                    local old_user=''${selection#* (}
                    old_user=''${old_user%)*}
                    
                    local new_user="$(get_user_input "Enter new username (current: $old_user): ")"
                    if [[ -n "$new_user" ]]; then
                        sed -i "s/$server=$old_user/$server=$new_user/" "$CREDS_FILE"
                        ${ui.messages.success "Server updated successfully."}
                    fi
                fi
                ;;
            "new")
                local server_ip="$(get_user_input "Enter server IP/hostname: ")"
                local username="$(get_user_input "Enter username: ")"
                if [[ -n "$server_ip" && -n "$username" ]]; then
                    save_new_server "$server_ip" "$username"
                    ${ui.messages.info "Testing connection..."}
                    if connect_to_server "$username@$server_ip" true; then
                        ${ui.messages.success "Connection successful!"}
                        add_ssh_key "$username" "$server_ip"
                    else
                        ${ui.messages.error "Could not connect to server. Please check credentials."}
                    fi
                fi
                ;;
            *)
                ${ui.messages.error "Unknown action: $action"}
                ;;
        esac
    }

    main() {
        # Get both selection and action from select_server
        local servers_list="$(load_saved_servers)"
        local selection
        local action
        
        # Read both lines from select_server
        { read -r selection; read -r action; } < <(select_server "$servers_list")
        
        if [[ -z "$selection" ]]; then
            ${ui.messages.error "No server selected"}
            exit 0
        fi
        
        handle_action "$selection" "$action"
    }

    main
  '';
in {
  config = {
    environment.systemPackages = [ connectScript ];
  };
}