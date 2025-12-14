{ config, lib, pkgs, moduleConfig, ... }:

with lib;

let
  ui = config.core.management.system-manager.submodules.cli-formatter.api;
  cfg = systemConfig.${moduleConfig.configPath};

  # Note: Scripts that use cfg must be created in mkIf cfg.enable block
in {
  config = mkIf cfg.enable (let
  # Main SSH Client Manager Script
  # This script provides the interactive interface for managing SSH connections
  sshClientManagerScript = pkgs.writeScriptBin "ncc-ssh-client-manager-main" ''
    #!${pkgs.bash}/bin/bash
        
    # Include server utilities, key utilities, and connection handler
    ${cfg.sshClientManagerServerUtils}
    ${cfg.sshClientManagerKeyUtils}
    ${cfg.sshConnectionHandler}

    # Handle different actions based on user selection
    # Parameters: selection (server choice), action (connect/delete/edit/new)
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
                    # Add new server workflow
                    echo -n "Enter server IP/hostname: "
                    read -r server_ip
                    echo -n "Enter username: "
                    read -r username
                    
                    if [[ -n "$server_ip" && -n "$username" ]]; then
                        # Get password once and store it temporarily for all operations
                        ${ui.messages.info "Password will only be asked once and used for key setup."}
                        local password="$(get_password_input "Password: ")"
                        echo # Add newline after password input
                        set_temp_password "$password"
                        
                        # Save server and setup SSH keys directly (no password test)
                        save_new_server "$server_ip" "$username"
                        
                        # Setup SSH keys directly (this will ask for password once)
                        ${ui.messages.info "Setting up SSH keys for passwordless login..."}
                        add_ssh_key_with_password "$username" "$server_ip" "$password"
                        
                        # Test key-based authentication after key setup
                        if connect_to_server "$username@$server_ip" true; then
                            ${ui.messages.success "Key-based authentication is now set up! You can log in without a password from now on."}
                            connect_to_server "$username@$server_ip"
                        else
                            ${ui.messages.warning "Key-based authentication failed after key setup. Please check the server's SSH configuration."}
                            # Connect with password since key setup failed
                            connect_to_server "$username@$server_ip" false true
                        fi
                        # Clear the password from memory when done
                        clear_temp_password
                    fi
                else
                    # Connect to existing server workflow
                    local server=''${selection%% *}
                    local user=''${selection#* (}
                    user=''${user%)*}
                    
                    # Try to connect directly first (key-based auth)
                    ${ui.messages.info "Connecting to $user@$server..."}
                    if connect_to_server "$user@$server" true; then
                        # Key-based authentication successful
                        ${ui.messages.success "Key-based authentication successful!"}
                        connect_to_server "$user@$server"
                    else
                        # Key-based auth failed, setup keys directly (no password test)
                        ${ui.messages.info "Key-based authentication failed. Setting up SSH keys for passwordless login..."}
                        local password="$(get_password_input "Password: ")"
                        echo # Add newline
                        set_temp_password "$password"
                        
                        # Setup SSH keys directly (this will ask for password once)
                        if add_ssh_key_with_password "$user" "$server" "$password"; then
                            # Test if key-based auth now works
                            if connect_to_server "$user@$server" true; then
                                ${ui.messages.success "SSH key setup successful! You can now connect without password."}
                                connect_to_server "$user@$server"
                            else
                                ${ui.messages.warning "SSH key setup completed but key-based auth still fails. Connecting with password."}
                                connect_to_server "$user@$server" false true
                            fi
                        else
                            ${ui.messages.warning "SSH key setup failed. Connecting with password."}
                            connect_to_server "$user@$server" false true
                        fi
                        clear_temp_password
                    fi
                fi
                ;;
            "delete")
                # Delete server from credentials file
                if [[ "$selection" != "Add new server" ]]; then
                    local server=''${selection%% *}
                    ${ui.messages.loading "Deleting server..."}
                    sed -i "/^$server=/d" "$CREDS_FILE"
                    ${ui.messages.success "Server deleted successfully."}
                fi
                ;;
            "edit")
                # Edit server username in credentials file
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
                # Quick add new server workflow
                local server_ip="$(get_user_input "Enter server IP/hostname: ")"
                local username="$(get_user_input "Enter username: ")"
                if [[ -n "$server_ip" && -n "$username" ]]; then
                    save_new_server "$server_ip" "$username"
                    ${ui.messages.info "Testing connection..."}
                    if connect_to_server "$username@$server_ip" true; then
                        # Key-based auth works, setup keys and connect
                        ${ui.messages.success "Connection successful!"}
                        add_ssh_key "$username" "$server_ip"
                        connect_to_server "$username@$server_ip"
                    else
                        # Key-based auth failed, setup keys directly (no password test)
                        ${ui.messages.info "Key-based authentication failed. Setting up SSH keys for passwordless login..."}
                        local password="$(get_password_input "Password: ")"
                        echo # Add newline
                        set_temp_password "$password"
                        
                        # Setup SSH keys directly (this will ask for password once)
                        add_ssh_key_with_password "$username" "$server_ip" "$password"
                        connect_to_server "$username@$server_ip" false true
                        clear_temp_password
                    fi
                fi
                ;;
            *)
                ${ui.messages.error "Unknown action: $action"}
                ;;
        esac
    }

    # Main function - entry point of the script
    main() {
        # Get both selection and action from select_server
        local servers_list="$(load_saved_servers)"
        local selection
        local action
        
        # Read both lines from select_server (selection and action)
        { read -r selection; read -r action; } < <(select_server "$servers_list")
        
        # Don't show error if user just pressed enter on Add new server
        if [[ -z "$selection" && "$action" != "new" ]]; then
            ${ui.messages.error "No server selected"}
            exit 0
        fi
        
        # Handle the selected action
        handle_action "$selection" "$action"
    }

    # Start the main function
    main
  '';
in {
    # Enable terminal-ui dependency
    # features.terminal-ui.enable removed (cli-formatter is Core) = true;
    
    # Add the SSH client manager script to system packages
    environment.systemPackages = [
      sshClientManagerScript  # SSH Client Manager Script wird als Systempaket hinzugefügt
    ];
    
    # Register the command in the command center
    core.management.system-manager.submodules.cli-registry.commands = [
      {
        name = "ssh-client-manager";
        description = "Manage SSH client connections";
        category = "network";
        script = "${sshClientManagerScript}/bin/ncc-ssh-client-manager-main";
        arguments = [
          "--test"
        ];
        dependencies = [ pkgs.openssh ];
        shortHelp = "Manage and configure SSH clients and connections";
        longHelp = ''
          Manage SSH client connections, configure settings, and perform various actions related to SSH.

          Options:
            --test       Run a test connection
        '';
      }
    ];

    # Store the script reference in the service configuration
    ${moduleConfig.configPath} = {
      sshClientManagerScript = sshClientManagerScript;
    };
  });
}
