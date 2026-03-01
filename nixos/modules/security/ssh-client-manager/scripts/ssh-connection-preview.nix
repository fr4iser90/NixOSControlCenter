{ pkgs, sshClientCfg }:

pkgs.writeShellScriptBin "ssh-connection-preview" ''
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
    if grep -q "^$server$" "/home/$USER/${sshClientCfg.credentialsFile}.favorites" 2>/dev/null; then
      echo "★ Favorite"
    else
      echo "☆ Not in favorites"
    fi

    port=$(grep "^$server=" "/home/$USER/${sshClientCfg.credentialsFile}" | grep -o ':[0-9]*' | cut -d':' -f2)
    echo "Port: ''${port:-22}"

    echo ""
    echo "Connection Status:"
    echo "================="
    
    # ✅ FIX: Implement caching for SSH connection status to reduce lag
    # Cache file: /tmp/ssh-preview-cache/$user@$server.cache
    # Cache expires after 30 seconds
    CACHE_DIR="/tmp/ssh-preview-cache"
    CACHE_KEY="$user@$server"
    CACHE_FILE="$CACHE_DIR/$CACHE_KEY.cache"
    CACHE_EXPIRY=30  # seconds
    
    # Create cache directory if it doesn't exist
    mkdir -p "$CACHE_DIR"
    
    # Check cache first
    connection_status=""
    server_details=""
    use_cache=false
    
    if [ -f "$CACHE_FILE" ]; then
      cache_age=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)))
      if [ $cache_age -lt $CACHE_EXPIRY ]; then
        # Cache is valid, read from cache
        cached_content=$(cat "$CACHE_FILE")
        connection_status=$(echo "$cached_content" | head -n 1)
        server_details=$(echo "$cached_content" | tail -n +2)
        use_cache=true
      fi
    fi
    
    # If cache miss or expired, test connection
    if [ "$use_cache" = false ]; then
      # ✅ FIX: Reduce timeout from 5 to 2 seconds for faster response
      if timeout 2 ${pkgs.openssh}/bin/ssh -o BatchMode=yes -o ConnectTimeout=2 "$user@$server" exit 2>/dev/null; then
        connection_status="✓ Credentials valid"
        # Fetch server details (with timeout to prevent hanging)
        server_details=$(timeout 2 ${pkgs.openssh}/bin/ssh -o BatchMode=yes "$user@$server" "uname -a" 2>/dev/null || echo "Unable to fetch system info")
      else
        connection_status="✗ Credentials invalid or Unreachable"
        server_details=""
      fi
      
      # Cache the result
      echo -e "$connection_status\n$server_details" > "$CACHE_FILE"
    fi
    
    # Display connection status
    echo "$connection_status"
    if [ -n "$server_details" ]; then
      echo ""
      echo "Server Details:"
      echo "=============="
      echo "$server_details"
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
''