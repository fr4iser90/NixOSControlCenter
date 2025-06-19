{ config, lib, pkgs, ... }:

let
  ui = config.features.terminal-ui.api;
  cfg = config.services.ssh-client-manager;

  # Centralized SSH Connection Handler
  # This module contains all SSH connection logic in one place
  sshConnectionHandler = ''
    # Centralized SSH Connection Handler
    # This module provides all SSH connection functionality
    
    # Temporary password storage (in memory only) - used to avoid multiple password prompts
    TEMP_PASSWORD=""

    # Main SSH connection function
    # Parameters:
    #   $1: full_server (user@host)
    #   $2: test_only (true/false) - if true, only test connection, don't establish session
    #   $3: use_password (true/false) - if true, use cached password with sshpass
    #   $4: batch_mode (true/false) - if true, use BatchMode=yes (no password prompts)
    connect_to_server() {
        local full_server="$1"
        local test_only="''${2:-false}"
        local use_password="''${3:-false}"
        local batch_mode="''${4:-false}"
        local status=0
        
        # Build SSH options
        local ssh_opts="-o StrictHostKeyChecking=no"
        
        if [[ "$batch_mode" == "true" ]]; then
            ssh_opts="$ssh_opts -o BatchMode=yes"
        fi
        
        if [[ "$test_only" == "true" ]]; then
            ssh_opts="$ssh_opts -o ConnectTimeout=5"
            
            if [[ "$use_password" == "true" && -n "$TEMP_PASSWORD" ]]; then
                # Use password authentication with sshpass for test connection
                local temp_pass_file=$(mktemp)
                echo "$TEMP_PASSWORD" > "$temp_pass_file"
                ssh_opts="$ssh_opts -o PreferredAuthentications=password -o PubkeyAuthentication=no"
                
                # Capture output to file and exit status separately
                ${pkgs.sshpass}/bin/sshpass -f "$temp_pass_file" ${pkgs.openssh}/bin/ssh $ssh_opts "$full_server" exit > /tmp/ssh-test.log 2>&1
                status=$?
                rm -f "$temp_pass_file"
            else
                # Use key-based authentication for test connection
                ${pkgs.openssh}/bin/ssh $ssh_opts "$full_server" exit > /tmp/ssh-test.log 2>&1
                status=$?
            fi
            return $status
        fi
        
        # Full connection (not test mode)
        if [[ "$use_password" == "true" && -n "$TEMP_PASSWORD" ]]; then
            # Use password authentication with sshpass for full connection
            local temp_pass_file=$(mktemp)
            echo "$TEMP_PASSWORD" > "$temp_pass_file"
            ssh_opts="$ssh_opts -o PreferredAuthentications=password -o PubkeyAuthentication=no"
            ${pkgs.sshpass}/bin/sshpass -f "$temp_pass_file" ${pkgs.openssh}/bin/ssh $ssh_opts "$full_server"
            local result=$?
            rm -f "$temp_pass_file"
            return $result
        else
            # Use key-based authentication for full connection
            ${pkgs.openssh}/bin/ssh $ssh_opts "$full_server"
        fi
    }

    # Test connection status (for preview)
    # Parameters: username, server
    # Returns: 0 if connection successful, 1 if failed
    test_connection_status() {
        local username="$1"
        local server="$2"
        connect_to_server "$username@$server" true false true
    }

    # Get server information (for preview)
    # Parameters: username, server
    # Returns: server information or error message
    get_server_info() {
        local username="$1"
        local server="$2"
        ${pkgs.openssh}/bin/ssh -o BatchMode=yes -o ConnectTimeout=5 "$username@$server" "uname -a" 2>/dev/null || echo "Unable to fetch system info"
    }

    # Copy SSH key to server using password
    # Parameters: username, server, password
    # Returns: 0 if successful, 1 if failed
    copy_ssh_key_with_password() {
        local username="$1"
        local server="$2"
        local password="$3"
        
        if [[ -n "$password" ]]; then
            local temp_pass_file=$(mktemp)
            echo "$password" > "$temp_pass_file"
            ${pkgs.sshpass}/bin/sshpass -f "$temp_pass_file" ${pkgs.openssh}/bin/ssh-copy-id -o StrictHostKeyChecking=no -i "$HOME/.ssh/id_rsa.pub" "$username@$server"
            local result=$?
            rm -f "$temp_pass_file"
            return $result
        else
            ${pkgs.openssh}/bin/ssh-copy-id -i "$HOME/.ssh/id_rsa.pub" "$username@$server"
            return $?
        fi
    }

    # Check if SSH key is already authorized on server
    # Parameters: username, server
    # Returns: 0 if authorized, 1 if not
    check_key_authorized() {
        local username="$1"
        local server="$2"
        local pubkey=$(cat "$HOME/.ssh/id_rsa.pub")
        ${pkgs.openssh}/bin/ssh -o BatchMode=yes "$username@$server" "grep -Fxq '$pubkey' ~/.ssh/authorized_keys" 2>/dev/null
    }

    # Clear the temporary password from memory for security
    clear_temp_password() {
        TEMP_PASSWORD=""
    }

    # Set temporary password for use in connections
    # Parameters: password
    set_temp_password() {
        TEMP_PASSWORD="$1"
    }
  '';
in {
  config = {
    services.ssh-client-manager = {
      sshConnectionHandler = sshConnectionHandler;
    };
  };
} 