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

hostname = configured hostName from network config (fallback: uname -n).
EOF
  }

  read_module_json() {
    local module_path="$1"
    local tmp_nix tmp_json
    tmp_nix=$(mktemp --suffix=.nix)
    tmp_json=$(mktemp --suffix=.json)
    ncc_read_module_config "$module_path" > "$tmp_nix" 2>/dev/null || printf '%s\n' '{}' > "$tmp_nix"
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
  sm=$(read_module_json "core/management/system-manager")
  net=$(read_module_json "core/base/network")

  runningHost=$(uname -n 2>/dev/null || echo "")
  configuredHost=$(echo "$net" | jq -r '.hostName // empty')
  # Prefer declared config hostName (what NCC manages); else live kernel name
  if [[ -n "$configuredHost" ]]; then
    host="$configuredHost"
  else
    host="$runningHost"
  fi

  # Never invent defaults — empty means unknown / missing config field
  configVersion=$(echo "$sm" | jq -r '.configVersion // empty')
  systemType=$(echo "$sm" | jq -r '.systemType // empty')
  if echo "$sm" | jq -e 'has("enableChecks")' >/dev/null 2>&1; then
    enableChecks=$(echo "$sm" | jq -r 'if .enableChecks == false then "false" else "true" end')
  else
    enableChecks=""
  fi
  channel=$(echo "$sm" | jq -r '.system.channel // .channel // empty')
  platform=$(echo "$sm" | jq -r '.system.platform // .platform // empty')
  declared=$(echo "$sm" | jq -r '.layout // empty')
  [[ -n "$declared" && "$layout" == "none" ]] && layout="$declared"

  if [[ "$json_out" == true ]]; then
    jq -nc \
      --arg hostname "$host" \
      --arg runningHostname "$runningHost" \
      --arg configuredHostname "$configuredHost" \
      --arg layout "$layout" \
      --arg configVersion "$configVersion" \
      --arg systemType "$systemType" \
      --arg channel "$channel" \
      --arg platform "$platform" \
      --arg enableChecks "$enableChecks" \
      --argjson sm "$sm" \
      '{
        hostname: $hostname,
        runningHostname: $runningHostname,
        configuredHostname: $configuredHostname,
        layout: $layout,
        configVersion: $configVersion,
        systemType: $systemType,
        channel: $channel,
        platform: $platform,
        enableChecks: (if $enableChecks == "" then null elif $enableChecks == "true" then true else false end),
        systemManager: $sm
      }'
  else
    echo "hostname=$host"
    echo "runningHostname=$runningHost"
    echo "configuredHostname=$configuredHost"
    echo "layout=$layout"
    echo "configVersion=$configVersion"
    echo "systemType=$systemType"
    echo "channel=$channel"
    echo "platform=$platform"
    echo "enableChecks=$enableChecks"
  fi
''
