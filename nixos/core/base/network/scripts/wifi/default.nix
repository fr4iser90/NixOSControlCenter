# ncc wifi CLI — connect, list, scan, status, disconnect, forget (system-only secrets)
{ pkgs, getModuleApi }:

let
  ui = getModuleApi "cli-formatter";
  nmcli = "${pkgs.networkmanager}/bin/nmcli";
  embedPsk = import ../../lib/embed-psk.nix { inherit pkgs; };
  python3 = "${pkgs.python3}/bin/python3";

  persistDir = "/var/lib/nixos-control-center/networkmanager-connections";
  secretsWifiDir = "/etc/nixos/secrets/wifi";
  liveDir = "/etc/NetworkManager/system-connections";

  commonShell = ''
    set -eu
    NMCLI="${nmcli}"
    PYTHON="${python3}"
    EMBED_PSK="${embedPsk}"
    PERSIST="${persistDir}"
    SECRETS_WIFI="${secretsWifiDir}"
    LIVE="${liveDir}"

    sanitize_name() {
      echo "$1" | tr ' /' '__' | tr -cd '[:alnum:]_.-'
    }

    valid_psk() {
      local psk="$1"
      [ -n "$psk" ] || return 1
      case "$psk" in
        *Wallet*|*walletd*|*DBus*|*Error*|*Couldn*|*"not found"*|*QDBus*) return 1 ;;
      esac
      local len="''${#psk}"
      [ "$len" -ge 8 ] || return 1
      [ "$len" -le 63 ] && return 0
      [ "$len" -eq 64 ] && echo "$psk" | grep -qE "^[0-9a-fA-F]{64}$"
    }

    wifi_device() {
      local dev typ
      while IFS=: read -r dev typ; do
        [ "$typ" = "wifi" ] && { echo "$dev"; return 0; }
      done < <("$NMCLI" -t -f DEVICE,TYPE device status 2>/dev/null || true)
      return 1
    }

    find_wifi_connection() {
      local name="$1"
      local uuid id profile_ssid type
      while IFS= read -r uuid; do
        [ -n "$uuid" ] || continue
        type="$("$NMCLI" -t -g connection.type connection show "$uuid" 2>/dev/null || true)"
        [ "$type" = "802-11-wireless" ] || continue
        id="$("$NMCLI" -t -g connection.id connection show "$uuid" 2>/dev/null || true)"
        profile_ssid="$("$NMCLI" -t -g 802-11-wireless.ssid connection show "$uuid" 2>/dev/null || true)"
        if [ "$id" = "$name" ] || [ "$profile_ssid" = "$name" ]; then
          echo "$id"
          return 0
        fi
      done < <("$NMCLI" -t -f UUID connection show 2>/dev/null || true)
      return 1
    }

    connect_wifi() {
      local ssid="$1" psk="$2" dev="$3"
      local conn_name=""

      conn_name="$(find_wifi_connection "$ssid" || true)"
      if [ -n "$conn_name" ]; then
        "$NMCLI" connection modify "$conn_name" \
          connection.id "$ssid" \
          802-11-wireless.ssid "$ssid" \
          802-11-wireless-security.key-mgmt wpa-psk \
          802-11-wireless-security.psk "$psk" \
          802-11-wireless-security.psk-flags 0 \
          connection.autoconnect yes 2>/dev/null || true
      else
        "$NMCLI" connection add type wifi \
          con-name "$ssid" \
          ifname "$dev" \
          ssid "$ssid" \
          wifi-sec.key-mgmt wpa-psk \
          wifi-sec.psk "$psk" \
          connection.autoconnect yes 2>/dev/null || return 1
      fi

      "$NMCLI" -w 60 connection up "$ssid" ifname "$dev" >/dev/null 2>&1 || return 1
      echo "$ssid"
    }

    persist_connection() {
      local ssid="$1" psk="$2"
      local stem out_file live_name conn_name
      if ! valid_psk "$psk"; then
        ${ui.messages.error "invalid password"}
        return 1
      fi
      stem="$(sanitize_name "$ssid")"
      out_file="$PERSIST/$stem.nmconnection"
      live_name="$stem.nmconnection"

      mkdir -p "$PERSIST" "$SECRETS_WIFI" "$LIVE"
      umask 077
      printf '%s' "$psk" > "$SECRETS_WIFI/$stem.psk"
      chmod 600 "$SECRETS_WIFI/$stem.psk"
      printf '%s' "$psk" > "$PERSIST/$stem.psk"
      chmod 600 "$PERSIST/$stem.psk"

      conn_name="$(find_wifi_connection "$ssid" || true)"
      [ -n "$conn_name" ] || conn_name="$ssid"

      "$NMCLI" connection modify "$conn_name" \
        connection.id "$ssid" \
        802-11-wireless.ssid "$ssid" \
        802-11-wireless-security.key-mgmt wpa-psk \
        802-11-wireless-security.psk "$psk" \
        802-11-wireless-security.psk-flags 0 \
        connection.autoconnect yes 2>/dev/null || true

      "$NMCLI" connection export "$ssid" "$out_file" 2>/dev/null || true
      if [ ! -f "$out_file" ]; then
        cat > "$out_file" <<EOF
[connection]
id=$ssid
type=802-11-wireless
autoconnect=true

[wifi]
mode=infrastructure
ssid=$ssid

[wifi-security]
key-mgmt=wpa-psk
psk=$psk
psk-flags=0
EOF
      fi
      "$PYTHON" "$EMBED_PSK" "$out_file" "$psk" 2>/dev/null || true
      chmod 600 "$out_file"
      install -m 0600 -D "$out_file" "$LIVE/$live_name"
      ${ui.messages.success "saved headless profile: $SECRETS_WIFI/$stem.psk"}
    }
  '';

  wifiHelp = pkgs.writeShellScriptBin "ncc-wifi" ''
    #!${pkgs.bash}/bin/bash
    ${commonShell}
    cat <<'HELP'
ncc network wifi — WiFi management (NetworkManager)

Usage:
  ncc network wifi scan [--json]         Scan for networks
  ncc network wifi list                  List saved WiFi profiles
  ncc network wifi status                Show WiFi / connection status
  ncc network wifi connect <SSID>        Connect and save password (system-only)
  ncc network wifi disconnect            Disconnect WiFi
  ncc network wifi forget <name|SSID>    Remove profile + system secret
  ncc network wifi on|off                Enable / disable WiFi radio

Connect options:
  --psk <password>               Password on command line (avoid in shared history)
  --psk-file <path>              Read password from file
  --dry-run, -d                  Preview only — nothing will be written

Mutating commands also accept --dry-run: connect, disconnect, forget.

Secrets are stored only on this system:
  /etc/nixos/secrets/wifi/<name>.psk
HELP
  '';

  wifiRouter = pkgs.writeShellScriptBin "ncc-wifi-router" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    cmd="''${1:-}"
    shift || true
    case "$cmd" in
      ""|help|-h|--help) exec ${wifiHelp}/bin/ncc-wifi ;;
      scan) exec ${wifiScan}/bin/ncc-wifi-scan "$@" ;;
      list) exec ${wifiList}/bin/ncc-wifi-list "$@" ;;
      status) exec ${wifiStatus}/bin/ncc-wifi-status "$@" ;;
      connect) exec ${wifiConnect}/bin/ncc-wifi-connect "$@" ;;
      disconnect) exec ${wifiDisconnect}/bin/ncc-wifi-disconnect "$@" ;;
      forget) exec ${wifiForget}/bin/ncc-wifi-forget "$@" ;;
      on|radio-on)
        if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
          ${ui.text.header "WiFi radio on"}
        fi
        ${pkgs.networkmanager}/bin/nmcli radio wifi on
        ${ui.messages.success "wifi radio=enabled"}
        if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
          ${ui.messages.info "Next: ncc network wifi scan"}
        fi
        ;;
      off|radio-off)
        if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
          ${ui.text.header "WiFi radio off"}
        fi
        ${pkgs.networkmanager}/bin/nmcli radio wifi off
        ${ui.messages.success "wifi radio=disabled"}
        if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
          ${ui.messages.info "Next: ncc network wifi on"}
        fi
        ;;
      *)
        ${ui.messages.error "Unknown: ncc network wifi $cmd"}
        if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
          ${ui.messages.info "Next: ncc network wifi help"}
        fi
        exit 1
        ;;
    esac
  '';


  wifiScan = pkgs.writeShellScriptBin "ncc-wifi-scan" ''
    #!${pkgs.bash}/bin/bash
    ${commonShell}
    JSON=false
    for a in "$@"; do
      case "$a" in --json|-j) JSON=true ;; esac
    done
    if [ "$JSON" != true ] && [ -z "''${NCC_CLI_NESTED:-}" ]; then
      ${ui.text.header "WiFi scan"}
    fi
    dev="$(wifi_device)"
    if [ -z "$dev" ]; then
      ${ui.messages.error "no WiFi device found"}
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        ${ui.messages.info "Next: ncc network status"}
      fi
      exit 1
    fi
    if [ "$JSON" != true ]; then
      ${ui.messages.loading "Scanning on $dev …"}
      ${ui.tables.keyValue "device" "$dev"}
    fi
    "$NMCLI" device wifi rescan ifname "$dev" 2>/dev/null || true
    sleep 2
    if [ "$JSON" = true ]; then
      "$NMCLI" -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list ifname "$dev" 2>/dev/null \
        | ${pkgs.jq}/bin/jq -R -s -c '
            split("\n")
            | map(select(length>0))
            | map(split(":"))
            | map(select(length>=2 and .[1] != ""))
            | map({
                in_use: (.[0] == "*"),
                ssid: .[1],
                signal: (.[2] // ""),
                security: (.[3] // "")
              })
          '
    else
      "$NMCLI" -f IN-USE,SSID,BSSID,CHAN,SIGNAL,SECURITY device wifi list ifname "$dev"
      ${ui.messages.success "Scan complete"}
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        ${ui.messages.info "Next: ncc network wifi connect <SSID>"}
      fi
    fi
  '';

  wifiList = pkgs.writeShellScriptBin "ncc-wifi-list" ''
    #!${pkgs.bash}/bin/bash
    ${commonShell}
    if [ -z "''${NCC_CLI_NESTED:-}" ]; then
      ${ui.text.header "WiFi list"}
    fi
    ${ui.messages.loading "Listing saved WiFi profiles…"}
    ${ui.text.section "NetworkManager WiFi connections"}
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      uuid="''${line%%:*}"
      type="$("$NMCLI" -g connection.type connection show "$uuid" 2>/dev/null || true)"
      [ "$type" = "802-11-wireless" ] || continue
      id="$("$NMCLI" -g connection.id connection show "$uuid" 2>/dev/null || true)"
      ssid="$("$NMCLI" -g 802-11-wireless.ssid connection show "$uuid" 2>/dev/null || true)"
      auto="$("$NMCLI" -g connection.autoconnect connection show "$uuid" 2>/dev/null || true)"
      active="$("$NMCLI" -g GENERAL.STATE connection show "$uuid" 2>/dev/null || true)"
      stem="$(sanitize_name "$id")"
      ssid_stem="$(sanitize_name "$ssid")"
      secret="no"
      if [ -f "$SECRETS_WIFI/$stem.psk" ]; then
        secret="yes (/etc/nixos/secrets/wifi/$stem.psk)"
      elif [ -n "$ssid_stem" ] && [ -f "$SECRETS_WIFI/$ssid_stem.psk" ]; then
        secret="yes (/etc/nixos/secrets/wifi/$ssid_stem.psk)"
      fi
      echo "  $id  ssid=$ssid  autoconnect=$auto  active=$active  headless-secret=$secret"
    done < <("$NMCLI" -t -f UUID connection show 2>/dev/null || true)

    echo ""
    ${ui.text.section "System secret files"}
    shopt -s nullglob
    files=("$SECRETS_WIFI"/*.psk)
    if [ ''${#files[@]} -eq 0 ]; then
      echo "  (none)"
    else
      for f in "''${files[@]}"; do
        echo "  $(basename "$f")"
      done
    fi
    ${ui.messages.success "WiFi list ready"}
    if [ -z "''${NCC_CLI_NESTED:-}" ]; then
      ${ui.messages.info "Next: ncc network wifi connect <SSID>"}
    fi
  '';

  wifiStatus = pkgs.writeShellScriptBin "ncc-wifi-status" ''
    #!${pkgs.bash}/bin/bash
    ${commonShell}
    if [ -z "''${NCC_CLI_NESTED:-}" ]; then
      ${ui.text.header "WiFi status"}
    fi
    ${ui.messages.loading "Reading WiFi status…"}
    ${ui.text.section "NetworkManager"}
    "$NMCLI" general status 2>/dev/null || true
    echo ""
    ${ui.text.section "Devices"}
    "$NMCLI" device status 2>/dev/null || true
    echo ""
    dev="$(wifi_device)"
    if [ -n "$dev" ]; then
      ${ui.text.section "Active connection on $dev"}
      "$NMCLI" -f GENERAL.CONNECTION,IP4.ADDRESS device show "$dev" 2>/dev/null || true
    fi
    ${ui.messages.success "WiFi status ready"}
    if [ -z "''${NCC_CLI_NESTED:-}" ]; then
      ${ui.messages.info "Next: ncc network wifi scan"}
    fi
  '';

  wifiConnect = pkgs.writeShellScriptBin "ncc-wifi-connect" ''
    #!${pkgs.bash}/bin/bash
    ${commonShell}

    ssid=""
    psk=""
    psk_file=""
    DRY_RUN=false

    while [ $# -gt 0 ]; do
      case "$1" in
        --psk) psk="$2"; shift 2 ;;
        --psk-file) psk_file="$2"; shift 2 ;;
        --dry-run|-d) DRY_RUN=true; shift ;;
        -h|--help)
          echo "usage: ncc network wifi connect <SSID> [--psk PASS | --psk-file PATH] [--dry-run]"
          exit 0
          ;;
        *)
          if [ -z "$ssid" ]; then
            ssid="$1"
          else
            ${ui.messages.error "unexpected argument: $1"}
            exit 1
          fi
          shift
          ;;
      esac
    done

    if [ -z "''${NCC_CLI_NESTED:-}" ]; then
      if [ "$DRY_RUN" = true ]; then
        ${ui.text.header "WiFi connect (dry-run)"}
        ${ui.messages.info "Preview only — nothing will be written…"}
      else
        ${ui.text.header "WiFi connect"}
      fi
    fi

    if [ -z "$ssid" ]; then
      ${ui.messages.error "SSID required"}
      echo "usage: ncc network wifi connect <SSID> [--psk PASS | --psk-file PATH] [--dry-run]" >&2
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        ${ui.messages.info "Next: ncc network wifi scan"}
      fi
      exit 1
    fi

    if [ "$DRY_RUN" = true ]; then
      ${ui.messages.loading "Previewing WiFi connect…"}
      ${ui.tables.keyValue "ssid" "$ssid"}
      if [ -n "$psk_file" ]; then
        ${ui.tables.keyValue "psk-file" "$psk_file"}
      elif [ -n "$psk" ]; then
        ${ui.tables.keyValue "psk" "(provided on CLI)"}
      else
        ${ui.tables.keyValue "psk" "(would prompt)"}
      fi
      dev="$(wifi_device || true)"
      if [ -n "$dev" ]; then
        ${ui.tables.keyValue "device" "$dev"}
      fi
      ${ui.messages.success "Would connect to '$ssid' and save system secret (dry-run) — no changes written"}
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        ${ui.messages.info "Next: sudo ncc network wifi connect $ssid"}
      fi
      exit 0
    fi

    if [ -n "$psk_file" ]; then
      if [ ! -f "$psk_file" ]; then
        ${ui.messages.error "psk file not found: $psk_file"}
        exit 1
      fi
      psk="$(cat "$psk_file")"
    elif [ -z "$psk" ]; then
      printf "WiFi password for '%s': " "$ssid" >&2
      read -rs psk
      echo >&2
    fi

    if ! valid_psk "$psk"; then
      ${ui.messages.error "invalid password (WPA needs 8-63 chars)"}
      exit 1
    fi

    dev="$(wifi_device)"
    if [ -z "$dev" ]; then
      ${ui.messages.error "no WiFi device found"}
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        ${ui.messages.info "Next: ncc network status"}
      fi
      exit 1
    fi

    ${ui.messages.loading "Connecting to '$ssid' on $dev …"}
    ${ui.tables.keyValue "ssid" "$ssid"}
    ${ui.tables.keyValue "device" "$dev"}
    conn_name="$(connect_wifi "$ssid" "$psk" "$dev" || true)"
    if [ -z "$conn_name" ]; then
      ${ui.messages.error "connection failed"}
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        ${ui.messages.info "Next: ncc network wifi scan"}
      fi
      exit 1
    fi

    persist_connection "$ssid" "$psk"
    ${ui.messages.success "connected: $ssid"}
    if [ -z "''${NCC_CLI_NESTED:-}" ]; then
      ${ui.messages.info "Next: ncc network wifi status"}
    fi
  '';

  wifiDisconnect = pkgs.writeShellScriptBin "ncc-wifi-disconnect" ''
    #!${pkgs.bash}/bin/bash
    ${commonShell}
    DRY_RUN=false
    for a in "$@"; do
      case "$a" in --dry-run|-d) DRY_RUN=true ;; esac
    done
    if [ -z "''${NCC_CLI_NESTED:-}" ]; then
      if [ "$DRY_RUN" = true ]; then
        ${ui.text.header "WiFi disconnect (dry-run)"}
        ${ui.messages.info "Preview only — nothing will be written…"}
      else
        ${ui.text.header "WiFi disconnect"}
      fi
    fi
    dev="$(wifi_device)"
    if [ -z "$dev" ]; then
      ${ui.messages.error "no WiFi device found"}
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        ${ui.messages.info "Next: ncc network status"}
      fi
      exit 1
    fi
    ${ui.messages.loading "Disconnecting $dev…"}
    ${ui.tables.keyValue "device" "$dev"}
    if [ "$DRY_RUN" = true ]; then
      ${ui.messages.success "Would disconnect $dev (dry-run) — no changes written"}
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        ${ui.messages.info "Next: ncc network wifi disconnect"}
      fi
      exit 0
    fi
    "$NMCLI" device disconnect "$dev"
    ${ui.messages.success "disconnected $dev"}
    if [ -z "''${NCC_CLI_NESTED:-}" ]; then
      ${ui.messages.info "Next: ncc network wifi scan"}
    fi
  '';

  wifiForget = pkgs.writeShellScriptBin "ncc-wifi-forget" ''
    #!${pkgs.bash}/bin/bash
    ${commonShell}

    name=""
    DRY_RUN=false
    for a in "$@"; do
      case "$a" in
        --dry-run|-d) DRY_RUN=true ;;
        -h|--help)
          echo "usage: ncc network wifi forget <connection-name|SSID> [--dry-run]"
          exit 0
          ;;
        *)
          if [ -z "$name" ]; then name="$a"; else
            ${ui.messages.error "unexpected argument: $a"}
            exit 1
          fi
          ;;
      esac
    done

    if [ -z "''${NCC_CLI_NESTED:-}" ]; then
      if [ "$DRY_RUN" = true ]; then
        ${ui.text.header "WiFi forget (dry-run)"}
        ${ui.messages.info "Preview only — nothing will be written…"}
      else
        ${ui.text.header "WiFi forget"}
      fi
    fi
    if [ -z "$name" ]; then
      ${ui.messages.error "usage: ncc wifi forget <connection-name|SSID> [--dry-run]"}
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        ${ui.messages.info "Next: ncc network wifi list"}
      fi
      exit 1
    fi

    conn_name=""
    while IFS= read -r uuid; do
      [ -n "$uuid" ] || continue
      type="$("$NMCLI" -g connection.type connection show "$uuid" 2>/dev/null || true)"
      [ "$type" = "802-11-wireless" ] || continue
      id="$("$NMCLI" -g connection.id connection show "$uuid" 2>/dev/null || true)"
      ssid="$("$NMCLI" -g 802-11-wireless.ssid connection show "$uuid" 2>/dev/null || true)"
      if [ "$id" = "$name" ] || [ "$ssid" = "$name" ]; then
        conn_name="$id"
        break
      fi
    done < <("$NMCLI" -t -f UUID connection show 2>/dev/null || true)

    if [ -z "$conn_name" ]; then
      ${ui.messages.error "no WiFi profile matching '$name'"}
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        ${ui.messages.info "Next: ncc network wifi list"}
      fi
      exit 1
    fi

    ${ui.messages.loading "Forgetting $conn_name…"}
    ${ui.tables.keyValue "profile" "$conn_name"}
    stem="$(sanitize_name "$conn_name")"
    if [ "$DRY_RUN" = true ]; then
      ${ui.messages.success "Would forget $conn_name and remove system secret (dry-run) — no changes written"}
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        ${ui.messages.info "Next: sudo ncc network wifi forget $conn_name"}
      fi
      exit 0
    fi
    "$NMCLI" connection delete "$conn_name" 2>/dev/null || true
    rm -f "$SECRETS_WIFI/$stem.psk" "$PERSIST/$stem.psk" \
      "$PERSIST/$stem.nmconnection" "$LIVE/$stem.nmconnection" 2>/dev/null || true
    ${ui.messages.success "forgot: $conn_name"}
    if [ -z "''${NCC_CLI_NESTED:-}" ]; then
      ${ui.messages.info "Next: ncc network wifi list"}
    fi
  '';

  commands = [
    {
      name = "wifi";
      domain = "wifi";
      type = "manager";
      description = "WiFi management (connect, list, scan)";
      category = "network";
      script = "${wifiHelp}/bin/ncc-wifi";
      requiresSudo = false;
      shortHelp = "wifi - WiFi management";
      longHelp = ''
        WiFi management via NetworkManager.

        Usage:
          ncc wifi scan
          ncc wifi list
          ncc wifi status
          ncc wifi connect <SSID> [--psk PASS | --psk-file PATH]
          ncc wifi disconnect
          ncc wifi forget <name>
      '';
    }
    {
      name = "scan";
      domain = "wifi";
      parent = "wifi";
      description = "Scan for WiFi networks";
      category = "network";
      script = "${wifiScan}/bin/ncc-wifi-scan";
      requiresSudo = false;
      shortHelp = "scan - Scan for WiFi networks";
      longHelp = "Scan for available WiFi networks: ncc wifi scan";
    }
    {
      name = "list";
      domain = "wifi";
      parent = "wifi";
      description = "List saved WiFi profiles and system secrets";
      category = "network";
      script = "${wifiList}/bin/ncc-wifi-list";
      requiresSudo = false;
      shortHelp = "list - List saved WiFi profiles";
      longHelp = "List WiFi connections and /etc/nixos/secrets/wifi/*.psk files";
    }
    {
      name = "status";
      domain = "wifi";
      parent = "wifi";
      description = "Show WiFi connection status";
      category = "network";
      script = "${wifiStatus}/bin/ncc-wifi-status";
      requiresSudo = false;
      shortHelp = "status - WiFi status";
      longHelp = "Show NetworkManager and WiFi device status";
    }
    {
      name = "connect";
      domain = "wifi";
      parent = "wifi";
      description = "Connect to WiFi and save password on system";
      category = "network";
      script = "${wifiConnect}/bin/ncc-wifi-connect";
      requiresSudo = true;
      shortHelp = "connect <SSID> - Connect and save";
      longHelp = ''
        Connect to a WiFi network and persist the password on this system only.

        Usage:
          ncc wifi connect MyNetwork
          ncc wifi connect MyNetwork --psk 'secret123'
          ncc wifi connect MyNetwork --psk-file /etc/nixos/secrets/wifi/MyNetwork.psk
      '';
    }
    {
      name = "disconnect";
      domain = "wifi";
      parent = "wifi";
      description = "Disconnect WiFi";
      category = "network";
      script = "${wifiDisconnect}/bin/ncc-wifi-disconnect";
      requiresSudo = true;
      shortHelp = "disconnect - Disconnect WiFi";
      longHelp = "Disconnect the WiFi device from the current network";
    }
    {
      name = "forget";
      domain = "wifi";
      parent = "wifi";
      description = "Remove WiFi profile and system secret";
      category = "network";
      script = "${wifiForget}/bin/ncc-wifi-forget";
      requiresSudo = true;
      shortHelp = "forget <name> - Remove profile";
      longHelp = "Delete a WiFi connection and remove its /etc/nixos/secrets/wifi/*.psk file";
    }
  ];
in
{
  inherit commands wifiRouter wifiHelp;
}
