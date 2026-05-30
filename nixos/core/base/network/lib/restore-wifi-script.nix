# Restore WiFi before NetworkManager — embed PSK from sidecar + secrets/wifi (no login)
{ pkgs, persistDir, liveDir, secretsWifiDir }:

let
  embedPsk = import ./embed-psk.nix { inherit pkgs; };
  logger = "${pkgs.util-linux}/bin/logger";
in
pkgs.writeShellScript "ncc-restore-wifi-profiles" ''
  set -eu
  PERSIST="${persistDir}"
  LIVE="${liveDir}"
  SECRETS_WIFI="${secretsWifiDir}"
  EMBED_PSK="${embedPsk}"
  LOGGER="${logger}"

  mkdir -p "$PERSIST" "$LIVE" "$SECRETS_WIFI"

  log() {
    "$LOGGER" -t ncc-wifi-restore "$*" 2>/dev/null || true
    echo "ncc-wifi-restore: $*" >&2
  }

  log "starting WiFi restore (before NetworkManager)"

  valid_psk() {
    local psk="$1"
    [ -n "$psk" ] || return 1
    [ "$psk" = "--" ] && return 1
    case "$psk" in
        *Wallet*|*walletd*|*DBus*|*Error*|*Couldn*|*"not found"*|*QDBus*|*org.freedesktop*|*org.kde*)
        return 1
        ;;
    esac
    local len="''${#psk}"
    [ "$len" -ge 8 ] || return 1
    [ "$len" -le 63 ] && return 0
    [ "$len" -eq 64 ] && echo "$psk" | grep -qE "^[0-9a-fA-F]{64}$"
  }

  read_valid_psk_file() {
    local f="$1" psk
    [ -f "$f" ] || return 1
    psk="$(cat "$f" 2>/dev/null || true)"
    valid_psk "$psk" || return 1
    echo "$psk"
  }

  embed_psk_in_keyfile() {
    local file="$1"
    local psk="$2"
    valid_psk "$psk" || return 0
    [ -f "$file" ] || return 0
    if ! ${pkgs.python3}/bin/python3 "$EMBED_PSK" "$file" "$psk"; then
      log "WARNING: embed PSK failed for $(basename "$file") — copying without embed"
      return 0
    fi
  }

  lookup_psk_for_profile() {
    local keyfile="$1"
    local conn_id ssid stem sidecar candidate psk
    conn_id="$(grep -m1 '^id=' "$keyfile" 2>/dev/null | cut -d= -f2- || true)"
    ssid="$(grep -m1 '^ssid=' "$keyfile" 2>/dev/null | cut -d= -f2- || true)"
    stem="$(basename "$keyfile" .nmconnection)"

    sidecar="$PERSIST/$stem.psk"
    psk="$(read_valid_psk_file "$sidecar" || true)"
    [ -n "$psk" ] && { echo "$psk"; return 0; }

    for candidate in \
      "$SECRETS_WIFI/$stem.psk" \
      "$SECRETS_WIFI/$conn_id.psk" \
      "$SECRETS_WIFI/$ssid.psk"; do
      psk="$(read_valid_psk_file "$candidate" || true)"
      [ -n "$psk" ] && { echo "$psk"; return 0; }
    done

    psk="$(grep -m1 '^psk=' "$keyfile" 2>/dev/null | cut -d= -f2- || true)"
    if valid_psk "$psk" && ! grep -q 'psk-flags=1' "$keyfile" 2>/dev/null; then
      echo "$psk"
    fi
  }

  shopt -s nullglob
  profiles=("$PERSIST"/*.nmconnection)
  if [ ''${#profiles[@]} -eq 0 ]; then
    log "no WiFi profiles in $PERSIST — nothing to restore"
    exit 0
  fi

  for f in "''${profiles[@]}"; do
    [ -f "$f" ] || continue
    psk="$(lookup_psk_for_profile "$f" || true)"
    conn_id="$(grep -m1 '^id=' "$f" 2>/dev/null | cut -d= -f2- || true)"
    stem="$(basename "$f" .nmconnection)"
    if valid_psk "$psk"; then
      log "embedding PSK for $conn_id"
      embed_psk_in_keyfile "$f" "$psk"
      umask 077
      printf '%s' "$psk" > "$PERSIST/$stem.psk" || true
      chmod 600 "$PERSIST/$stem.psk" 2>/dev/null || true
    else
      log "WARNING: no valid PSK for $conn_id — profile copied but will not autoconnect headless"
      rm -f "$PERSIST/$stem.psk" "$SECRETS_WIFI/$stem.psk" 2>/dev/null || true
    fi
    install -m 0600 -D "$f" "$LIVE/$(basename "$f")" || log "WARNING: install to LIVE failed for $(basename "$f")"
  done
  log "restore complete"
  exit 0
''
