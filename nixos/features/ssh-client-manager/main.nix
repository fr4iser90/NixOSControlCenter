{ config, lib, pkgs, ... }:

let
  ui = config.features.terminal-ui.api;
  cfg = config.services.ssh-client-manager;
  
  sshClientManagerScript = pkgs.writeScriptBin "ncc-ssh-client-manager-main" ''
    #!${pkgs.bash}/bin/bash
        
    ${cfg.sshClientManagerServerUtils}
    ${cfg.sshClientManagerKeyUtils}

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
                    echo -n "Enter server IP/hostname: "
                    read -r server_ip
                    echo -n "Enter username: "
                    read -r username
                    
                    if [[ -n "$server_ip" && -n "$username" ]]; then
                        # Get password once and store it temporarily
                        ${ui.messages.info "Password will only be asked once and used for all steps (connection and key setup)."}
                        TEMP_PASSWORD="$(get_password_input "Password: ")"
                        echo # Add newline after password input
                        
                        ${ui.messages.info "Testing connection..."}
                        if connect_to_server "$username@$server_ip" true true; then
                            save_new_server "$server_ip" "$username"
                            
                            # Use the cached password for key setup
                            add_ssh_key_with_password "$username" "$server_ip" "$TEMP_PASSWORD"
                            
                            # Immediately test key-based login after key setup
                            if connect_to_server "$username@$server_ip" true; then
                                ${ui.messages.success "Key-based authentication is now set up! You can log in without a password from now on."}
                                connect_to_server "$username@$server_ip"
                            else
                                ${ui.messages.warning "Key-based authentication failed after key setup. Please check the server's SSH configuration."}
                            fi
                        else
                            ${ui.messages.error "Connection test failed. Server not saved."}
                        fi
                        # Clear the password when done with all operations
                        clear_temp_password
                    fi
                else
                    local server=''${selection%% *}
                    local user=''${selection#* (}
                    user=''${user%)*}
                    
                    # For existing servers, first try key-based auth
                    ${ui.messages.info "Trying connection to $user@$server..."}
                    if connect_to_server "$user@$server" true; then
                        ${ui.messages.success "Key-based authentication successful!"}
                        connect_to_server "$user@$server"
                    else
                        # If key auth fails, ask for password and try again
                        ${ui.messages.info "Key-based authentication failed. Password will only be asked once and used for all steps (connection and key setup)."}
                        TEMP_PASSWORD="$(get_password_input "Password: ")"
                        echo # Add newline
                        
                        if connect_to_server "$user@$server" true true; then
                            ${ui.messages.success "Password authentication successful!"}
                            add_ssh_key_with_password "$user" "$server" "$TEMP_PASSWORD"
                            # Immediately test key-based login after key setup
                            if connect_to_server "$user@$server" true; then
                                ${ui.messages.success "Key-based authentication is now set up! You can log in without a password from now on."}
                                connect_to_server "$user@$server"
                            else
                                ${ui.messages.warning "Key-based authentication failed after key setup. Please check the server's SSH configuration."}
                            fi
                        else
                            ${ui.messages.error "Connection failed with both key and password."}
                        fi
                        clear_temp_password
                    fi
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
                        connect_to_server "$username@$server_ip"
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
        
        # Don't show error if user just pressed enter on Add new server
        if [[ -z "$selection" && "$action" != "new" ]]; then
            ${ui.messages.error "No server selected"}
            exit 0
        fi
        
        handle_action "$selection" "$action"
    }

    main
  '';
in {
  config = {
    environment.systemPackages = [
      sshClientManagerScript  # SSH Client Manager Skript wird als Systempaket hinzugefügt
    ];
    
    features.command-center.commands = [
      {
        name = "ssh-client-manager";
        description = "Manage SSH client connections";
        category = "network";
        script = "${sshClientManagerScript}/bin/ncc-ssh-client-manager-main";  # Setze den Pfad zum SSH Client Manager Skript
        arguments = [
          "--test"  # Beispielargument, passe es nach Bedarf an
        ];
        dependencies = [ pkgs.openssh ];  # Füge hier Pakete hinzu, die für den SSH-Client Manager benötigt werden
        shortHelp = "Manage and configure SSH clients and connections";
        longHelp = ''
          Manage SSH client connections, configure settings, and perform various actions related to SSH.
          
          Options:
            --test       Run a test connection
        '';
      }
    ];

    services.ssh-client-manager = {
      sshClientManagerScript = sshClientManagerScript;
    };
  };
}
