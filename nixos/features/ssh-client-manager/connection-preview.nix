{ config, lib, pkgs, ... }:

let
  cfg = config.features.ssh-client-manager;

  # Connection Preview Script
  # This script provides detailed information about SSH servers in the FZF preview window
  connectionPreviewScript = pkgs.writeScriptBin "ssh-connection-preview" ''
    #!${pkgs.bash}/bin/bash
    
    # Include connection handler
    ${cfg.sshConnectionHandler}
    
    line="$1"
    
    if [[ "$line" == "Add new server" ]]; then
      # Show help information for adding new servers
      echo "Add a new SSH server connection"
      echo ""
      echo "Shortcuts:"
      echo "  enter - Start new server wizard"
      echo "  esc   - Cancel"
    else
      # Parse server information from the selected line
      server=''${line%% *}
      user=''${line#* (}
      user=''${user%)*}
      
      # Display server information
      echo "Server Information:"
      echo "==================="
      echo "Server: $server"
      echo "User: $user"
      
      # Show SSH key information
      echo ""
      echo "SSH Keys:"
      echo "========="
      ssh-keygen -l -f "/home/$USER/.ssh/id_rsa" 2>/dev/null || echo "No default RSA key found"
      
      # Show favorite status
      echo ""
      echo "Status:"
      echo "======="
      if grep -q "^$server$" "/home/$USER/${cfg.credentialsFile}.favorites" 2>/dev/null; then
        echo "★ Favorite"
      else
        echo "☆ Not in favorites"
      fi
      
      # Show SSH port information
      port=$(grep "^$server=" "/home/$USER/${cfg.credentialsFile}" | grep -o ':[0-9]*' | cut -d':' -f2)
      echo "Port: ''${port:-22}"
      
      # Test connection status
      echo ""
      echo "Connection Status:"
      echo "================="
      if test_connection_status "$user" "$server"; then
        echo "✓ Credentials valid"
        echo ""
        echo "Server Details:"
        echo "=============="
        get_server_info "$user" "$server"
      else
        echo "✗ Credentials invalid or Unreachable"
      fi
      
      # Show available actions
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

in {
  config = {
    features.ssh-client-manager = {
      connectionPreviewScript = connectionPreviewScript;
    };
  };
}
