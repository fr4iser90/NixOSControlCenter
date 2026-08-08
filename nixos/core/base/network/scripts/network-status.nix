{ pkgs }:

let
  nmcli = "${pkgs.networkmanager}/bin/nmcli";

  common = ''
    set -euo pipefail
    NMCLI="${nmcli}"

    read_hostname() {
      if [[ -r /etc/hostname ]]; then
        tr -d '[:space:]' < /etc/hostname
      else
        uname -n 2>/dev/null || echo unknown
      fi
    }

    device_of_type() {
      local want="$1" dev typ
      while IFS=: read -r dev typ; do
        [ "$typ" = "$want" ] && { echo "$dev"; return 0; }
      done < <("$NMCLI" -t -f DEVICE,TYPE device status 2>/dev/null || true)
      return 1
    }

    device_state() {
      local want_dev="$1" d s _
      while IFS=: read -r d s _; do
        [ "$d" = "$want_dev" ] && { echo "$s"; return 0; }
      done < <("$NMCLI" -t -f DEVICE,STATE,CONNECTION device status 2>/dev/null || true)
      echo "unknown"
    }

    device_connection() {
      local want_dev="$1" d s c
      while IFS=: read -r d s c; do
        [ "$d" = "$want_dev" ] && { echo "$c"; return 0; }
      done < <("$NMCLI" -t -f DEVICE,STATE,CONNECTION device status 2>/dev/null || true)
      echo ""
    }

    device_ipv4() {
      local dev="$1"
      "$NMCLI" -t -g IP4.ADDRESS device show "$dev" 2>/dev/null | head -1 | cut -d/ -f1 || true
    }

    device_gateway() {
      local dev="$1"
      "$NMCLI" -t -g IP4.GATEWAY device show "$dev" 2>/dev/null | head -1 || true
    }

    wifi_radio() {
      local r
      r="$("$NMCLI" radio wifi 2>/dev/null | tr '[:upper:]' '[:lower:]' | awk '{print $1}' || true)"
      case "$r" in
        enabled|disabled) echo "$r" ;;
        *) echo "unknown" ;;
      esac
    }
  '';

  statusScript = pkgs.writeShellScriptBin "ncc-network-status" ''
    #!${pkgs.bash}/bin/bash
    ${common}
    JSON=false
    for a in "$@"; do
      case "$a" in
        --json|-j) JSON=true ;;
        --help|-h)
          echo "Usage: ncc network status [--json]"
          exit 0
          ;;
      esac
    done

    HN="$(read_hostname)"
    WIFI_DEV="$(device_of_type wifi || true)"
    ETH_DEV="$(device_of_type ethernet || true)"
    RADIO="$(wifi_radio)"

    ONLINE=false
    conn_chk="$("$NMCLI" networking connectivity check 2>/dev/null || "$NMCLI" networking connectivity 2>/dev/null || true)"
    case "$conn_chk" in
      *full*|*limited*|*portal*) ONLINE=true ;;
    esac

    wifi_present=false
    wifi_state=""
    wifi_conn=""
    wifi_ip=""
    if [[ -n "$WIFI_DEV" ]]; then
      wifi_present=true
      wifi_state="$(device_state "$WIFI_DEV")"
      wifi_conn="$(device_connection "$WIFI_DEV")"
      [[ "$wifi_conn" == "--" ]] && wifi_conn=""
      wifi_ip="$(device_ipv4 "$WIFI_DEV")"
    fi

    eth_present=false
    eth_state=""
    eth_conn=""
    eth_ip=""
    eth_gw=""
    if [[ -n "$ETH_DEV" ]]; then
      eth_present=true
      eth_state="$(device_state "$ETH_DEV")"
      eth_conn="$(device_connection "$ETH_DEV")"
      [[ "$eth_conn" == "--" ]] && eth_conn=""
      eth_ip="$(device_ipv4 "$ETH_DEV")"
      eth_gw="$(device_gateway "$ETH_DEV")"
    fi

    if [[ "$JSON" == true ]]; then
      ${pkgs.jq}/bin/jq -n \
        --arg hn "$HN" \
        --argjson online "$ONLINE" \
        --argjson wifi_present "$wifi_present" \
        --arg wifi_dev "$WIFI_DEV" \
        --arg wifi_radio "$RADIO" \
        --arg wifi_state "$wifi_state" \
        --arg wifi_conn "$wifi_conn" \
        --arg wifi_ip "$wifi_ip" \
        --argjson eth_present "$eth_present" \
        --arg eth_dev "$ETH_DEV" \
        --arg eth_state "$eth_state" \
        --arg eth_conn "$eth_conn" \
        --arg eth_ip "$eth_ip" \
        --arg eth_gw "$eth_gw" \
        '{
          hostname: $hn,
          online: $online,
          wifi: {
            present: $wifi_present,
            device: $wifi_dev,
            radio: $wifi_radio,
            state: $wifi_state,
            connection: $wifi_conn,
            ipv4: $wifi_ip
          },
          ethernet: {
            present: $eth_present,
            device: $eth_dev,
            state: $eth_state,
            connection: $eth_conn,
            ipv4: $eth_ip,
            gateway: $eth_gw
          }
        }'
      exit 0
    fi

    echo "hostname=$HN"
    echo "online=$ONLINE"
    echo "wifi.present=$wifi_present"
    echo "wifi.device=$WIFI_DEV"
    echo "wifi.radio=$RADIO"
    echo "wifi.state=$wifi_state"
    echo "wifi.connection=$wifi_conn"
    echo "wifi.ipv4=$wifi_ip"
    echo "ethernet.present=$eth_present"
    echo "ethernet.device=$ETH_DEV"
    echo "ethernet.state=$eth_state"
    echo "ethernet.connection=$eth_conn"
    echo "ethernet.ipv4=$eth_ip"
    echo "ethernet.gateway=$eth_gw"
  '';

  ethernetRouter = pkgs.writeShellScriptBin "ncc-ethernet-router" ''
    #!${pkgs.bash}/bin/bash
    ${common}
    cmd="''${1:-}"
    shift || true
    case "$cmd" in
      ""|help|-h|--help)
        cat <<EOF
ncc network ethernet — wired link (NetworkManager)

Usage:
  ncc network ethernet status [--json]
  ncc network ethernet disconnect
  ncc network ethernet reconnect
EOF
        exit 0
        ;;
      status)
        JSON=false
        for a in "$@"; do
          case "$a" in --json|-j) JSON=true ;; esac
        done
        ETH_DEV="$(device_of_type ethernet || true)"
        if [[ -z "$ETH_DEV" ]]; then
          if [[ "$JSON" == true ]]; then
            echo '{"present":false}'
          else
            echo "ethernet.present=false"
          fi
          exit 0
        fi
        st="$(device_state "$ETH_DEV")"
        conn="$(device_connection "$ETH_DEV")"
        [[ "$conn" == "--" ]] && conn=""
        ip="$(device_ipv4 "$ETH_DEV")"
        gw="$(device_gateway "$ETH_DEV")"
        if [[ "$JSON" == true ]]; then
          ${pkgs.jq}/bin/jq -n \
            --argjson present true \
            --arg device "$ETH_DEV" \
            --arg state "$st" \
            --arg connection "$conn" \
            --arg ipv4 "$ip" \
            --arg gateway "$gw" \
            '{present:$present,device:$device,state:$state,connection:$connection,ipv4:$ipv4,gateway:$gateway}'
        else
          echo "ethernet.present=true"
          echo "ethernet.device=$ETH_DEV"
          echo "ethernet.state=$st"
          echo "ethernet.connection=$conn"
          echo "ethernet.ipv4=$ip"
          echo "ethernet.gateway=$gw"
        fi
        ;;
      disconnect)
        ETH_DEV="$(device_of_type ethernet || true)"
        if [[ -z "$ETH_DEV" ]]; then
          echo "error: no ethernet device" >&2
          exit 1
        fi
        "$NMCLI" device disconnect "$ETH_DEV"
        echo "disconnected $ETH_DEV"
        ;;
      reconnect|connect)
        ETH_DEV="$(device_of_type ethernet || true)"
        if [[ -z "$ETH_DEV" ]]; then
          echo "error: no ethernet device" >&2
          exit 1
        fi
        conn="$(device_connection "$ETH_DEV")"
        if [[ -n "$conn" && "$conn" != "--" ]]; then
          "$NMCLI" connection up "$conn" ifname "$ETH_DEV" || "$NMCLI" device connect "$ETH_DEV"
        else
          "$NMCLI" device connect "$ETH_DEV"
        fi
        echo "connected $ETH_DEV"
        ;;
      *)
        echo "Unknown: ncc network ethernet $cmd" >&2
        exit 1
        ;;
    esac
  '';
in
{
  inherit statusScript ethernetRouter;
}
