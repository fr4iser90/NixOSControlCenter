# Force WiFi connection at boot after NetworkManager starts (no user session required)
{ pkgs, persistDir, liveDir, secretsWifiDir }:

let
  logger = "${pkgs.util-linux}/bin/logger";
  nmcli = "${pkgs.networkmanager}/bin/nmcli";
  sleep = "${pkgs.coreutils}/bin/sleep";
in
pkgs.writeShellScript "ncc-wifi-autoconnect" ''
  set -eu
  PERSIST="${persistDir}"
  LIVE="${liveDir}"
  SECRETS_WIFI="${secretsWifiDir}"
  NMCLI="${nmcli}"
  LOGGER="${logger}"
  SLEEP="${sleep}"

  log() {
    "$LOGGER" -t ncc-wifi-autoconnect "$*" 2>/dev/null || true
    echo "ncc-wifi-autoconnect: $*" >&2
  }

  wifi_device() {
    local dev typ
    while IFS=: read -r dev typ; do
      [ "$typ" = "wifi" ] && { echo "$dev"; return 0; }
    done < <("$NMCLI" -t -f DEVICE,TYPE device status 2>/dev/null || true)
    return 1
  }

  profile_conn_id() {
    grep -m1 '^id=' "$1" 2>/dev/null | cut -d= -f2- || true
  }

  log "bringing up saved WiFi profiles (headless)"

  "$NMCLI" radio wifi on 2>/dev/null || true

  dev=""
  i=0
  while [ "$i" -lt 45 ]; do
    dev="$(wifi_device || true)"
    [ -n "$dev" ] && break
    i=$((i + 1))
    "$SLEEP" 1
  done

  if [ -z "$dev" ]; then
    log "no WiFi device found — giving up"
    exit 0
  fi

  log "using device $dev"
  "$NMCLI" device set "$dev" managed yes 2>/dev/null || true
  "$NMCLI" connection reload 2>/dev/null || true
  "$SLEEP" 2

  shopt -s nullglob
  profiles=("$PERSIST"/*.nmconnection)
  if [ ''${#profiles[@]} -eq 0 ]; then
    for f in "$SECRETS_WIFI"/*.psk; do
      [ -f "$f" ] || continue
      stem="$(basename "$f" .psk)"
      live="$LIVE/$stem.nmconnection"
      [ -f "$live" ] && profiles+=("$live")
    done
  fi

  if [ ''${#profiles[@]} -eq 0 ]; then
    log "no profiles to activate"
    exit 0
  fi

  for f in "''${profiles[@]}"; do
    conn_id="$(profile_conn_id "$f")"
    [ -n "$conn_id" ] || continue
    state="$("$NMCLI" -t -g GENERAL.STATE device show "$dev" 2>/dev/null | tr -d '\r' || true)"
    case "$state" in
      *connected*) log "$conn_id already connected on $dev"; exit 0 ;;
    esac
    log "activating $conn_id on $dev"
    if "$NMCLI" -w 45 connection up "$conn_id" ifname "$dev" >/dev/null 2>&1; then
      log "connected: $conn_id"
      exit 0
    fi
    log "WARNING: connection up failed for $conn_id"
  done

  exit 0
''
