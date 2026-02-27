{ lib, pkgs, cfg }:

pkgs.writeShellScriptBin "chronicle-tray" ''
  #!/usr/bin/env bash

  if ! command -v ${pkgs.yad}/bin/yad &> /dev/null; then
    echo "YAD not found. Install with: nix-shell -p yad"
    exit 1
  fi

  get_status() {
    if chronicle status 2>/dev/null | grep -q "Recording active"; then
      echo "recording"
    else
      echo "idle"
    fi
  }

  while true; do
    status=$(get_status)

    if [ "$status" = "recording" ]; then
      icon="media-record"
      tooltip="Step Recorder - Recording Active"
    else
      icon="media-playback-pause"
      tooltip="Step Recorder - Idle"
    fi

    ${pkgs.yad}/bin/yad --notification \
      --image="$icon" \
      --text="$tooltip" \
      --menu="Start Recording!chronicle start --daemon!media-record|\
Stop Recording!chronicle stop!media-playback-stop|\
Quick Capture!chronicle capture!camera-photo|\
Open GUI!chronicle-gui!preferences-system|\
Quit!killall -9 yad!application-exit" &

    PID=$!
    sleep 5
    kill $PID 2>/dev/null || true
  done
''
