{ pkgs, getModuleApi }:

let
  paths = import ../lib/paths.nix;
  ui = getModuleApi "cli-formatter";
in
pkgs.writeShellScriptBin "ncc-hyprland-rice-verify" ''
  set -euo pipefail

  usage() {
    cat <<EOF
ncc hyprland rice verify — hard gate before Hyprland login (no session switch)

Runs: hyprland --verify-config against the LIVE files under /etc/xdg/hypr/
Stay in KDE/Plasma. Only log into Hyprland if this prints SAFE TO LOGIN.

Usage:
  ncc hyprland rice verify
EOF
  }

  case "''${1:-}" in
    --help|-h) usage; exit 0 ;;
  esac

  LUA="${paths.hyprConfigDestLua}"
  CONF="${paths.hyprConfigDest}"
  CFG=""

  if [[ -f "$LUA" ]]; then
    CFG="$LUA"
  elif [[ -f "$CONF" ]]; then
    CFG="$CONF"
  else
    ${ui.messages.error "No deployed Hyprland config at $LUA or $CONF"}
    ${ui.messages.info "Next: apply a rice, rebuild, then re-run verify before login"}
    exit 1
  fi

  if [[ "$CFG" == *.lua ]]; then
    parent="$(dirname "$CFG")"
    if [[ ! -d "$parent/config" ]] && grep -qE 'require\s*\(' "$CFG" 2>/dev/null; then
      ${ui.messages.error "Lua entry has require() but $parent/config/ is missing — login WOULD crash"}
      ${ui.messages.info "Next: ncc system-update --local (needs full-tree deploy), then rebuild"}
      exit 1
    fi
  fi

  out=$(mktemp)
  set +e
  ${pkgs.hyprland}/bin/hyprland --verify-config -c "$CFG" >"$out" 2>&1
  rc=$?
  set -e

  # Strip ANSI; keep the useful lines
  clean=$(${pkgs.gnused}/bin/sed 's/\x1b\[[0-9;]*m//g' "$out" || true)
  rm -f "$out"

  if echo "$clean" | grep -qi 'config ok' && [[ "$rc" -eq 0 ]]; then
    echo "config: $CFG"
    echo "hyprland --verify-config: config ok"
    ${ui.messages.success "SAFE TO LOGIN — Hyprland config parses; this crash class will not hit"}
    ${ui.messages.info "Still in KDE? Log out → pick Hyprland session. Missing bars/apps are separate from this gate."}
    exit 0
  fi

  echo "config: $CFG" >&2
  echo "$clean" | ${pkgs.gnugrep}/bin/grep -vE '^(DEBUG|========|$)' >&2 || echo "$clean" >&2
  ${ui.messages.error "DO NOT LOGIN — Hyprland config would fail at session start"}
  ${ui.messages.info "Stay on your current session. Fix rice / re-deploy, then verify again."}
  exit 1
''
