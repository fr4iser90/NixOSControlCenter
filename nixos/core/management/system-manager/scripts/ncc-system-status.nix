# ncc system status — read system-manager config via facade (monolith or split)
{ pkgs, getModuleMetadata }:

let
  smRoot = (getModuleMetadata "system-manager").path;
  facade = import "${smRoot}/lib/config-facade.nix" { inherit pkgs; };
in
pkgs.writeShellScriptBin "ncc-system-status" ''
  set -euo pipefail
  export PATH="${pkgs.jq}/bin:${pkgs.coreutils}/bin:${pkgs.nix}/bin:$PATH"

  NIXOS_DIR="''${NIXOS_DIR:-/etc/nixos}"
  ${facade.sourcePreamble { nixosRoot = "/etc/nixos"; }}
  export NIXOS_ROOT="$NIXOS_DIR"
  export CONFIGS_BASE="$NIXOS_DIR/systemConfig"
  export MONOLITH_FILE="$NIXOS_DIR/systemConfig.nix"

  usage() {
    cat <<EOF
ncc system status — Overview of system-manager config (facade)

Usage:
  ncc system status [--json]

Reads core.management.system-manager via the config facade (works for
monolith systemConfig.nix and split systemConfig/**/config.nix).
EOF
  }

  read_sm_json() {
    local tmp_nix tmp_json
    tmp_nix=$(mktemp --suffix=.nix)
    tmp_json=$(mktemp --suffix=.json)
    ncc_read_module_config "core/management/system-manager" > "$tmp_nix" 2>/dev/null || printf '%s\n' '{}' > "$tmp_nix"
    if ! nix-instantiate --eval --strict --json -E "import $tmp_nix" > "$tmp_json" 2>/dev/null; then
      printf '%s\n' '{}' > "$tmp_json"
    fi
    cat "$tmp_json"
    rm -f "$tmp_nix" "$tmp_json"
  }

  json_out=false
  for a in "$@"; do
    case "$a" in
      --json|-j) json_out=true ;;
      -h|--help|help) usage; exit 0 ;;
    esac
  done

  layout=$(ncc_detect_layout)
  sm=$(read_sm_json)
  host=$(uname -n 2>/dev/null || echo "")

  configVersion=$(echo "$sm" | jq -r '.configVersion // "2.0"')
  systemType=$(echo "$sm" | jq -r '.systemType // "desktop"')
  enableChecks=$(echo "$sm" | jq -r 'if .enableChecks == false then "false" else "true" end')
  channel=$(echo "$sm" | jq -r '.system.channel // .channel // "—"')
  # Prefer live detect; fall back to declared layout field
  declared=$(echo "$sm" | jq -r '.layout // empty')
  [[ -n "$declared" && "$layout" == "none" ]] && layout="$declared"

  if [[ "$json_out" == true ]]; then
    jq -nc \
      --arg hostname "$host" \
      --arg layout "$layout" \
      --arg configVersion "$configVersion" \
      --arg systemType "$systemType" \
      --arg channel "$channel" \
      --argjson enableChecks "$( [[ "$enableChecks" == true ]] && echo true || echo false )" \
      --argjson sm "$sm" \
      '{
        hostname: $hostname,
        layout: $layout,
        configVersion: $configVersion,
        systemType: $systemType,
        channel: $channel,
        enableChecks: $enableChecks,
        systemManager: $sm
      }'
  else
    echo "hostname=$host"
    echo "layout=$layout"
    echo "configVersion=$configVersion"
    echo "systemType=$systemType"
    echo "channel=$channel"
    echo "enableChecks=$enableChecks"
  fi
''
