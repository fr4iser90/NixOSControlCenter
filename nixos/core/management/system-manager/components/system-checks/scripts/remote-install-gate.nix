# Remote install gate — thin orchestrator; logic lives in prebuild-check-* (SSOT).
{ pkgs, getModuleApi }:

let
  ui = getModuleApi "cli-formatter";

  remoteInstallGate = pkgs.writeScriptBin "ncc-remote-install-gate" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    NIXOS_DIR="''${NIXOS_DIR:-/etc/nixos}"
    FLAKE_ATTR="''${1:-''${NCC_FLAKE_ATTR:-nixos}}"
    export NCC_REMOTE_NONINTERACTIVE="''${NCC_REMOTE_NONINTERACTIVE:-1}"

    _run() {
      local bin="$1"
      if command -v "$bin" >/dev/null 2>&1; then
        "$bin"
        return 0
      fi
      ${ui.badges.error "Remote install: $bin not on PATH"}
      ${ui.messages.info "On first install Host push_tree pipes each check script via SSH"}
      return 127
    }

    ${ui.text.header "Remote install gate"}

    export NCC_PREFLIGHT_VERBOSE="''${NCC_PREFLIGHT_VERBOSE:-0}"
    _run prebuild-check-users

    export NCC_PREFLIGHT_MODE=compare
    _run prebuild-check-platform
    _run prebuild-check-cpu
    _run prebuild-check-gpu
    _run prebuild-check-memory

    if command -v ncc-migrate-config >/dev/null 2>&1; then
      ncc-migrate-config || ${ui.badges.warning "migrate-config failed (continuing)"}
    elif command -v ncc >/dev/null 2>&1; then
      ncc system migrate-config 2>/dev/null || true
    fi

    live="/tmp/ncc-live-flake-backup.nix"
    incoming="$NIXOS_DIR/flake.nix"
    merged="/tmp/ncc-flake-merged.nix"
    if [ -f "$live" ] && [ -f "$incoming" ] \
      && command -v ncc-check-flake-extras >/dev/null 2>&1 \
      && command -v ncc-merge-flake-extras >/dev/null 2>&1; then
      set +e
      ncc-check-flake-extras --live "$live" --incoming "$incoming" --json >/dev/null 2>&1
      rc=$?
      set -e
      if [ "$rc" -eq 2 ]; then
        ncc-merge-flake-extras --live "$live" --incoming "$incoming" --out "$merged" \
          && cp -a "$merged" "$incoming" \
          && ${ui.badges.success "Flake extras merged"}
      fi
    fi

    flake_ref="$NIXOS_DIR#$FLAKE_ATTR"
    if command -v ncc >/dev/null 2>&1; then
      export NCC_CLI_NESTED=1
      exec ncc system build switch --force --flake "$flake_ref"
    fi
    HOME=/root exec ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake "$flake_ref"
  '';

in
{
  inherit remoteInstallGate;
}
