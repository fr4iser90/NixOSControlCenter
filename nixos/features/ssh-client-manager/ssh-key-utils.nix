{ config, lib, pkgs, ... }:

let
  ui = config.features.terminal-ui.api;
  cfg = config.services.ssh-client-manager;

  sshClientManagerKeyUtils = ''
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

    add_ssh_key() {
        local username="$1"
        local server="$2"

        # Überprüfen, ob ein SSH-Schlüssel bereits vorhanden ist
        if [[ ! -f "$HOME/.ssh/id_rsa.pub" ]]; then
            ${ui.messages.info "SSH key not found. Generating a new SSH key."}
            ${pkgs.openssh}/bin/ssh-keygen -t ${toString cfg.keyType} -b ${toString cfg.keyBits} -f "$HOME/.ssh/id_rsa" -N ""
        fi

        # Überprüfen, ob der Schlüssel bereits auf dem Remote-Server autorisiert ist
        local pubkey=$(cat "$HOME/.ssh/id_rsa.pub")
        if ! ssh "$username@$server" "grep -Fxq '$pubkey' ~/.ssh/authorized_keys"; then
            ${ui.messages.info "Copying SSH key to the remote server..."}
            ${pkgs.openssh}/bin/ssh-copy-id -i "$HOME/.ssh/id_rsa.pub" "$username@$server"
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

    # New function that uses a provided password for SSH key copying
    add_ssh_key_with_password() {
        local username="$1"
        local server="$2"
        local password="$3"

        # Überprüfen, ob ein SSH-Schlüssel bereits vorhanden ist
        if [[ ! -f "$HOME/.ssh/id_rsa.pub" ]]; then
            ${ui.messages.info "SSH key not found. Generating a new SSH key."}
            ${pkgs.openssh}/bin/ssh-keygen -t ${toString cfg.keyType} -b ${toString cfg.keyBits} -f "$HOME/.ssh/id_rsa" -N ""
        fi

        # Use the provided password with sshpass
        ${ui.messages.info "Copying SSH key to the remote server..."}
        if [[ -n "$password" ]]; then
            if ${pkgs.sshpass}/bin/sshpass -p "$password" ${pkgs.openssh}/bin/ssh-copy-id -o StrictHostKeyChecking=no -i "$HOME/.ssh/id_rsa.pub" "$username@$server"; then
                ${ui.messages.success "SSH key successfully copied to $server"}
                return 0
            else
                ${ui.messages.error "Failed to copy SSH key to $server"}
                return 1
            fi
        else
            # Fall back to standard method if no password provided
            if ${pkgs.openssh}/bin/ssh-copy-id -i "$HOME/.ssh/id_rsa.pub" "$username@$server"; then
                ${ui.messages.success "SSH key successfully copied to $server"}
                return 0
            else
                ${ui.messages.error "Failed to copy SSH key to $server"}
                return 1
            fi
        fi
    }
  '';
in {
  config = {
    services.ssh-client-manager = {
      sshClientManagerKeyUtils = sshClientManagerKeyUtils;
    };
  };
}
