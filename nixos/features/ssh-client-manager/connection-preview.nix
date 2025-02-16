{ config, lib, pkgs, ... }:

let
  cfg = config.services.ssh-client-manager;

  connectionPreviewScript = pkgs.writeScriptBin "ssh-connection-preview" ''
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
      
      echo ""
      echo "SSH Keys:"
      echo "========="
      ssh-keygen -l -f "/home/$USER/.ssh/id_rsa" 2>/dev/null || echo "No default RSA key found"
      
      echo ""
      echo "Status:"
      echo "======="
      if grep -q "^$server$" "/home/$USER/${cfg.credentialsFile}.favorites" 2>/dev/null; then
        echo "★ Favorite"
      else
        echo "☆ Not in favorites"
      fi
      
      port=$(grep "^$server=" "/home/$USER/${cfg.credentialsFile}" | grep -o ':[0-9]*' | cut -d':' -f2)
      echo "Port: ''${port:-22}"
      
      echo ""
      echo "Connection Status:"
      echo "================="
      if ${pkgs.openssh}/bin/ssh -o BatchMode=yes -o ConnectTimeout=5 "$user@$server" exit 2>/dev/null; then
        echo "✓ Connected"
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

in {
  config = {
    services.ssh-client-manager = {
      connectionPreviewScript = connectionPreviewScript;
    };
  };
}
