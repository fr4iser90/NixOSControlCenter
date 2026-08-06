{ pkgs, getModuleApi }:

let
  ui = getModuleApi "cli-formatter";
  facade = import ../lib/config-facade.nix { inherit pkgs; };
in
pkgs.writeShellScriptBin "ncc-allow-unfree" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail

  NIXOS_DIR="''${NIXOS_DIR:-/etc/nixos}"
  ${facade.sourcePreamble { nixosRoot = "/etc/nixos"; }}
  export NIXOS_ROOT="$NIXOS_DIR"
  export CONFIGS_BASE="$NIXOS_DIR/systemConfig"
  export MONOLITH_FILE="$NIXOS_DIR/systemConfig.nix"

  DO_REBUILD=false
  for arg in "$@"; do
    case "$arg" in
      --rebuild|-r) DO_REBUILD=true ;;
      --help|-h)
        cat <<EOF
ncc system allow-unfree — enable nixpkgs.config.allowUnfree via systemConfig

Writes: core.management.system-manager.allowUnfree = true

NCC template default is already true for new installs. Older configs (or
explicit false) need this when you install unfree packages (zoom, steam, …).

Usage:
  sudo ncc system allow-unfree
  sudo ncc system allow-unfree --rebuild

Options:
  --rebuild, -r   After enabling, run: ncc system build switch
  --help, -h      Show this help
EOF
        exit 0
        ;;
    esac
  done

  if [ "''${EUID:-$(id -u)}" -ne 0 ]; then
    ${ui.messages.error "Run as root: sudo ncc system allow-unfree"}
    exit 1
  fi

  sm=$(ncc_read_module_config "core/management/system-manager" 2>/dev/null || echo "{}")

  if echo "$sm" | grep -qE 'allowUnfree[[:space:]]*=[[:space:]]*true'; then
    ${ui.messages.success "allowUnfree is already true"}
    exit 0
  fi

  if echo "$sm" | grep -qE 'allowUnfree[[:space:]]*=[[:space:]]*false'; then
    sm=$(echo "$sm" | sed -E 's/allowUnfree[[:space:]]*=[[:space:]]*false[[:space:]]*;/allowUnfree = true;/')
  elif echo "$sm" | grep -qE 'systemType[[:space:]]*='; then
    sm=$(echo "$sm" | sed -E 's/(systemType[[:space:]]*=[[:space:]]*"[^"]*"[[:space:]]*;)/\1\n  allowUnfree = true;/')
  elif [ "$sm" = "{}" ] || [ -z "$(echo "$sm" | tr -d '[:space:]')" ]; then
    sm='{
  configVersion = "2.0";
  layout = "monolith";
  systemType = "desktop";
  allowUnfree = true;
}'
  else
    # Insert before closing brace of attrset
    sm=$(printf '%s\n' "$sm" | ${pkgs.gnused}/bin/sed '$ i\  allowUnfree = true;')
  fi

  ncc_write_module_config "core/management/system-manager" "$sm"
  ${ui.messages.success "Set allowUnfree = true in systemConfig (system-manager)"}
  ${ui.messages.info "This maps to nixpkgs.config.allowUnfree in the flake."}

  if [ "$DO_REBUILD" = true ]; then
    host=$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo nixos)
    ${ui.messages.loading "Building with allowUnfree enabled..."}
    exec ncc system build switch --flake "$NIXOS_DIR#$host"
  else
    ${ui.messages.info "Next: sudo ncc system build switch"}
    ${ui.messages.info "Or:    sudo ncc system allow-unfree --rebuild"}
  fi
''
