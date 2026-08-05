{ pkgs, lib, checkReleaseScript, onCalendar ? "weekly" }:

let
  notifyScript = pkgs.writeScriptBin "ncc-release-notify" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    set +e
    OUTPUT=$(${checkReleaseScript}/bin/ncc-check-release --quiet 2>&1)
    EXIT=$?
    set -e

    if [ "$EXIT" -eq 0 ]; then
      exit 0
    fi

    if [ "$EXIT" -ne 10 ]; then
      ${pkgs.systemd}/bin/systemd-cat -t ncc-release-check -p err \
        echo "ncc-check-release failed (exit $EXIT): $OUTPUT"
      exit "$EXIT"
    fi

    # Re-run without --quiet for a readable journal/desktop message
    DETAIL=$(${checkReleaseScript}/bin/ncc-check-release 2>&1 || true)
    MSG=$(echo "$DETAIL" | ${pkgs.gnugrep}/bin/grep -E 'Update available:' | ${pkgs.coreutils}/bin/head -1 || true)
    MSG="''${MSG:-New NixOS stable release available — run: ncc system check-release}"

    ${pkgs.systemd}/bin/systemd-cat -t ncc-release-check -p warning echo "$MSG"
    echo "$DETAIL" | ${pkgs.systemd}/bin/systemd-cat -t ncc-release-check -p info

    if command -v notify-send >/dev/null 2>&1; then
      ${pkgs.libnotify}/bin/notify-send -u normal "NixOS update available" "$MSG" || true
    fi

    exit 0
  '';
in {
  inherit notifyScript;

  nixosConfig = {
    environment.systemPackages = [ notifyScript pkgs.libnotify ];

    systemd.services.ncc-release-check = {
      description = "Check for new NixOS stable releases (NCC)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${notifyScript}/bin/ncc-release-notify";
      };
    };

    systemd.timers.ncc-release-check = {
      description = "Periodic NixOS release check (NCC)";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = onCalendar;
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}
