{ config, lib, pkgs, ... }:

let
  ui = config.features.terminal-ui.api;
  cfg = config.services.ssh-manager;
  
  # Helper function to generate FZF preview text
  previewScript = pkgs.writeScriptBin "ssh-preview" ''
    #!${pkgs.bash}/bin/bash
    line="$1"
    
    if [[ "$line" == "Add new server" ]]; then
      echo "Add a new SSH server connection"
      echo ""
      echo "Shortcuts:"
      echo "  enter - Start new server wizard"
      echo "  esc   - Cancel"
    else
      server=''${line%% *}
      user=''${line#* (}
      user=''${user%)*}
      
      echo "Server Information:"
      echo "==================="
      echo "Server: $server"
      echo "User: $user"
      
      # Get SSH key information
      echo ""
      echo "SSH Keys:"
      echo "========="
      ssh-keygen -l -f "/home/$USER/.ssh/id_rsa" 2>/dev/null || echo "No default RSA key found"
      
      # Check if server is in favorites
      echo ""
      echo "Status:"
      echo "======="
      if grep -q "^$server$" "/home/$USER/${cfg.credentialsFile}.favorites" 2>/dev/null; then
        echo "★ Favorite"
      else
        echo "☆ Not in favorites"
      fi
      
      # Get port information
      port=$(grep "^$server=" "/home/$USER/${cfg.credentialsFile}" | grep -o ':[0-9]*' | cut -d':' -f2)
      echo "Port: ''${port:-22}"
      
      # Connection test
      echo ""
      echo "Connection Status:"
      echo "================="
      if ${pkgs.openssh}/bin/ssh -o BatchMode=yes -o ConnectTimeout=5 "$user@$server" exit 2>/dev/null; then
        echo "✓ Connected"
        
        # Get server information if connected
        echo ""
        echo "Server Details:"
        echo "=============="
        ${pkgs.openssh}/bin/ssh -o BatchMode=yes "$user@$server" "uname -a" 2>/dev/null || echo "Unable to fetch system info"
      else
        echo "✗ Unreachable"
      fi
      
      echo ""
      echo "Available Actions:"
      echo "================="
      echo "  enter    - Connect to server"
      echo "  ctrl-x   - Delete server"
      echo "  ctrl-e   - Edit server details"
      echo "  ctrl-f   - Toggle favorite"
      echo "  ctrl-p   - Change port"
      echo "  ctrl-k   - Manage SSH keys"
      echo "  ctrl-r   - Rotate SSH key"
      echo "  ctrl-b   - Backup SSH keys"
      echo "  ctrl-t   - Test connection"
    fi
  '';

  serverUtils = ''
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
              --preview "${previewScript}/bin/ssh-preview {}" \
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

  sshKeyUtils = ''
    generate_ssh_key() {
      local server="$1"
      local key_file="/home/$USER/.ssh/id_rsa_''${server//./_}"
      
      ${ui.messages.loading "Generating new SSH key for $server..."}
      ssh-keygen -t rsa -b 4096 -f "$key_file" -N "" -C "$USER@$server"
      ${ui.messages.success "Generated new SSH key: $key_file"}
      
      echo "Would you like to copy this key to the server? (y/n)"
      read -r response
      if [[ "$response" =~ ^[Yy]$ ]]; then
        ssh-copy-id -i "$key_file" "$server"
      fi
    }

    rotate_ssh_key() {
      local server="$1"
      local old_key="/home/$USER/.ssh/id_rsa_''${server//./_}"
      local new_key="$old_key.new"
      
      ${ui.messages.loading "Rotating SSH key for $server..."}
      
      # Generate new key
      ssh-keygen -t rsa -b 4096 -f "$new_key" -N "" -C "$USER@$server"
      
      # Copy new key to server
      if ssh-copy-id -i "$new_key" "$server"; then
        # Backup old key
        mv "$old_key" "$old_key.bak"
        mv "$old_key.pub" "$old_key.pub.bak"
        
        # Move new key to primary location
        mv "$new_key" "$old_key"
        mv "$new_key.pub" "$old_key.pub"
        
        ${ui.messages.success "Successfully rotated SSH key for $server"}
      else
        ${ui.messages.error "Failed to copy new key to server. Keeping old key."}
        rm "$new_key" "$new_key.pub"
      fi
    }

    backup_ssh_keys() {
      local backup_dir="/home/$USER/.ssh/backups/$(date +%Y%m%d_%H%M%S)"
      
      ${ui.messages.loading "Backing up SSH keys..."}
      mkdir -p "$backup_dir"
      cp /home/$USER/.ssh/id_* "$backup_dir/"
      chmod 600 "$backup_dir"/*
      ${ui.messages.success "SSH keys backed up to $backup_dir"}
    }
  '';
in {
  config = {
    services.ssh-manager = {
      utils = serverUtils + sshKeyUtils;
    };
  };
}