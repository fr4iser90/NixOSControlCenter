# Example: isp-daily-reconnect-monitor — public IPv4 / ISP forced reconnect during a nightly window.
# Import → timer + script active. Tune the let block below.
# Events append to: ~/.local/state/isp-daily-reconnect-monitor/<eventLogFileName>
# nixos/custom/default.nix skips example_*.nix — import explicitly.
{ config, lib, pkgs, ... }:

let
  # ---------------------------------------------------------------------------
  # Edit here
  # ---------------------------------------------------------------------------
  timeWindowStart = 3;
  timeWindowEnd = 4;
  monitorUser = "CHANGE_ME";
  enableLinger = false;
  publicIpUrl = "https://ipv4.icanhazip.com";
  curlMaxTime = 12;
  stateFileName = "last-public-ipv4";
  eventLogFileName = "events.log";
  notifyOnRecover = true;
  extraNotifyCommand = null;
  # ---------------------------------------------------------------------------

  pad2 = h: lib.fixedWidthString 2 "0" (toString h);

  hourInWindow = h: start: end:
    if start < end then h >= start && h < end
    else if start > end then h >= start || h < end
    else false;

  hoursInWindow = lib.filter (h: hourInWindow h timeWindowStart timeWindowEnd) (lib.range 0 23);

  calendarEntries = map (h: "*-*-* ${pad2 h}:*:00") hoursInWindow;

  extraNotifyLine =
    if extraNotifyCommand == null then
      "EXTRA_NOTIFY_COMMAND="
    else
      "EXTRA_NOTIFY_COMMAND=${lib.escapeShellArg extraNotifyCommand}";

  scriptBody = ''
    set -euo pipefail
    CURL="${lib.getExe pkgs.curl}"
    NOTIFY="${lib.getExe pkgs.libnotify}"

    CHECK_URL=${lib.escapeShellArg publicIpUrl}
    WIN_START=${toString timeWindowStart}
    WIN_END=${toString timeWindowEnd}
    CURL_MAX=${toString curlMaxTime}
    NOTIFY_ON_RECOVER=${if notifyOnRecover then "1" else "0"}
    ${extraNotifyLine}

    STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/isp-daily-reconnect-monitor"
    STATE_FILE="$STATE_DIR/${stateFileName}"
    LOG_FILE="$STATE_DIR/${eventLogFileName}"
    mkdir -p "$STATE_DIR"
    INIT_FLAG="$STATE_DIR/.initialized"

    hour=$((10#$(date +%H)))
    in_win=0
    if [[ "$WIN_START" -lt "$WIN_END" ]]; then
      [[ "$hour" -ge "$WIN_START" && "$hour" -lt "$WIN_END" ]] && in_win=1
    elif [[ "$WIN_START" -gt "$WIN_END" ]]; then
      [[ "$hour" -ge "$WIN_START" || "$hour" -lt "$WIN_END" ]] && in_win=1
    fi
    [[ "$in_win" -eq 1 ]] || exit 0

    log_event() {
      printf '[isp-daily-reconnect-monitor] %s %s\n' "$(date -Iseconds)" "$*" >>"$LOG_FILE" || true
    }

    run_extra() {
      [[ -z "''${EXTRA_NOTIFY_COMMAND:-}" ]] && return 0
      export NOTIFY_TITLE NOTIFY_BODY
      bash -c "$EXTRA_NOTIFY_COMMAND"
    }

    notify_desktop() {
      local title="$1"
      local body="$2"
      NOTIFY_TITLE="$title" NOTIFY_BODY="$body" \
        "$NOTIFY" -a "isp-daily-reconnect-monitor" "$title" "$body" 2>/dev/null || true
      run_extra
    }

    prev=""
    [[ -f "$STATE_FILE" ]] && prev="$(head -n1 "$STATE_FILE" | tr -d '[:space:]')"

    ip=""
    ip="$("$CURL" -4 -fsS --max-time "$CURL_MAX" "$CHECK_URL" | tr -d '[:space:]' || true)"

    if [[ -z "$ip" ]]; then
      if [[ -n "$prev" ]]; then
        log_event "event=outage reason=no_public_ipv4 previous_ip=$prev"
        notify_desktop "Netz / öffentliche IP" "Keine öffentliche IPv4 lesbar (vorher: $prev)."
        : >"$STATE_FILE"
      fi
      exit 0
    fi

    if [[ -z "$prev" ]]; then
      printf '%s\n' "$ip" >"$STATE_FILE"
      if [[ ! -f "$INIT_FLAG" ]]; then
        touch "$INIT_FLAG"
        log_event "event=baseline ip=$ip (first run, no notification)"
        exit 0
      fi
      if [[ "$NOTIFY_ON_RECOVER" == "1" ]]; then
        log_event "event=recover ip=$ip"
        notify_desktop "Wieder online" "Öffentliche IPv4: $ip"
      else
        log_event "event=recover ip=$ip (notify disabled)"
      fi
      exit 0
    fi

    if [[ "$ip" == "$prev" ]]; then
      exit 0
    fi

    log_event "event=ip_change from=$prev to=$ip"
    notify_desktop "Öffentliche IP gewechselt" "$prev → $ip"
    printf '%s\n' "$ip" >"$STATE_FILE"
  '';

  checkBin = pkgs.writeShellScriptBin "isp-daily-reconnect-check" scriptBody;
in
{
  assertions = [
    {
      assertion = (lib.length hoursInWindow) > 0;
      message = "isp_daily_reconnect_monitor.nix: empty time window (timeWindowStart/timeWindowEnd).";
    }
  ]
  ++ lib.optionals enableLinger [
    {
      assertion = builtins.hasAttr monitorUser config.users.users;
      message = "isp_daily_reconnect_monitor.nix: enableLinger needs monitorUser to exist in users.users.";
    }
  ];

  environment.systemPackages = [ checkBin ];

  users.users = lib.mkIf enableLinger { ${monitorUser}.linger = true; };

  systemd.user.services."isp-daily-reconnect-monitor" = {
    description = "isp-daily-reconnect-monitor: poll public IPv4 in configured time window";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe checkBin;
    };
  };

  systemd.user.timers."isp-daily-reconnect-monitor" = {
    description = "isp-daily-reconnect-monitor: run check each minute inside the hour window";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = calendarEntries;
      Persistent = true;
      Unit = "isp-daily-reconnect-monitor.service";
    };
  };
}
