{ pkgs, sshClientCfg, getModuleApi }:

let
  ui = getModuleApi "cli-formatter";
in
pkgs.writeShellScriptBin "ncc-ssh-connection-preview" ''
  #!${pkgs.bash}/bin/bash
  line="$1"

  if [[ "$line" == "Add new server" ]]; then
    ${ui.messages.info "Add a new SSH server connection"}
    echo ""
    ${ui.text.subsection "Shortcuts"}
    echo "  enter - Start new server wizard"
    echo "  esc   - Cancel"
  else
    server=''${line%% *}
    user=''${line#* (}
    user=''${user%)*}

    ${ui.text.section "Server Information"}
    ${ui.tables.keyValue "Server" "$server"}
    ${ui.tables.keyValue "User" "$user"}

    echo ""
    ${ui.text.section "SSH Keys"}
    ssh-keygen -l -f "/home/$USER/.ssh/id_rsa" 2>/dev/null || ${ui.messages.warning "No default RSA key found"}

    echo ""
    ${ui.text.section "Status"}
    if grep -q "^$server$" "/home/$USER/${sshClientCfg.credentialsFile}.favorites" 2>/dev/null; then
      ${ui.badges.info "Favorite"}
    else
      ${ui.messages.detailLevel "info" "Not in favorites"}
    fi

    port=$(grep "^$server=" "/home/$USER/${sshClientCfg.credentialsFile}" | grep -o ':[0-9]*' | cut -d':' -f2)
    ${ui.tables.keyValue "Port" "''${port:-22}"}

    echo ""
    ${ui.text.section "Connection Status"}

    # Cache file: /tmp/ssh-preview-cache/$user@$server.cache (expires after 30s)
    CACHE_DIR="/tmp/ssh-preview-cache"
    CACHE_KEY="$user@$server"
    CACHE_FILE="$CACHE_DIR/$CACHE_KEY.cache"
    CACHE_EXPIRY=30

    mkdir -p "$CACHE_DIR"

    conn_ok=""
    server_details=""
    use_cache=false

    if [ -f "$CACHE_FILE" ]; then
      cache_age=$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)))
      if [ $cache_age -lt $CACHE_EXPIRY ]; then
        cached_content=$(cat "$CACHE_FILE")
        conn_ok=$(echo "$cached_content" | head -n 1)
        server_details=$(echo "$cached_content" | tail -n +2)
        use_cache=true
      fi
    fi

    if [ "$use_cache" = false ]; then
      if timeout 2 ${pkgs.openssh}/bin/ssh -o BatchMode=yes -o ConnectTimeout=2 "$user@$server" exit 2>/dev/null; then
        conn_ok="ok"
        server_details=$(timeout 2 ${pkgs.openssh}/bin/ssh -o BatchMode=yes "$user@$server" "uname -a" 2>/dev/null || echo "Unable to fetch system info")
      else
        conn_ok="fail"
        server_details=""
      fi
      printf '%s\n%s\n' "$conn_ok" "$server_details" > "$CACHE_FILE"
    fi

    if [ "$conn_ok" = "ok" ]; then
      ${ui.badges.success "Credentials valid"}
    else
      ${ui.badges.error "Credentials invalid or unreachable"}
    fi
    if [ -n "$server_details" ]; then
      echo ""
      ${ui.text.section "Server Details"}
      echo "$server_details"
    fi

    echo ""
    ${ui.text.section "Available Actions"}
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
