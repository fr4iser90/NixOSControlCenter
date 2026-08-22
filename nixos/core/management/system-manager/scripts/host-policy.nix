{ pkgs, getModuleApi }:

let
  ui = getModuleApi "cli-formatter";
  facade = import ../lib/config-facade.nix { inherit pkgs; };
in
pkgs.writeShellScriptBin "ncc-host-policy" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail

  NIXOS_DIR="''${NIXOS_DIR:-/etc/nixos}"
  ${facade.sourcePreamble { nixosRoot = "/etc/nixos"; }}
  export NIXOS_ROOT="$NIXOS_DIR"
  export CONFIGS_BASE="$NIXOS_DIR/systemConfig"
  export MONOLITH_FILE="$NIXOS_DIR/systemConfig.nix"

  DO_REBUILD=false
  SET_DANGER=""
  SET_AUTO=""

  usage() {
    cat <<EOF
ncc system host-policy — set host confirm / auto-build policy in systemConfig

Writes:
  core/management/nixos-control-center  → dangerousIgnore
  core/management/system-manager        → autoBuild

Usage:
  sudo ncc system host-policy --dangerous-ignore=true|false --auto-build=true|false
  sudo ncc system host-policy --dangerous-ignore=true --auto-build=true --rebuild

Options:
  --dangerous-ignore=BOOL   Skip cli-registry dangerous yes/no
  --auto-build=BOOL         After system update: build+switch without y/n
  --rebuild, -r             After write: ncc system build switch
  --help, -h
EOF
  }

  parse_bool() {
    case "$1" in
      true|TRUE|1|yes|YES|on|ON) echo true ;;
      false|FALSE|0|no|NO|off|OFF) echo false ;;
      *) return 1 ;;
    esac
  }

  for arg in "$@"; do
    case "$arg" in
      --rebuild|-r) DO_REBUILD=true ;;
      --dangerous-ignore=*)
        SET_DANGER=$(parse_bool "''${arg#--dangerous-ignore=}") || {
          ${ui.messages.error "Invalid --dangerous-ignore (use true|false)"}
          exit 2
        }
        ;;
      --auto-build=*)
        SET_AUTO=$(parse_bool "''${arg#--auto-build=}") || {
          ${ui.messages.error "Invalid --auto-build (use true|false)"}
          exit 2
        }
        ;;
      --help|-h) usage; exit 0 ;;
      *)
        ${ui.messages.error "Unknown argument: $arg"}
        usage
        exit 2
        ;;
    esac
  done

  if [ -z "$SET_DANGER" ] && [ -z "$SET_AUTO" ]; then
    usage
    exit 2
  fi

  if [ "''${EUID:-$(id -u)}" -ne 0 ]; then
    ${ui.messages.error "Run as root: sudo ncc system host-policy …"}
    exit 1
  fi

  if [ -z "''${NCC_CLI_NESTED:-}" ]; then
    ${ui.text.header "Host safety policy"}
  fi

  # Read leaf Nix → set/replace bool key → write full leaf back (facade merge).
  set_bool_key() {
    local content="$1" key="$2" val="$3"
    if echo "$content" | grep -qE "$key[[:space:]]*="; then
      printf '%s\n' "$content" | ${pkgs.gnused}/bin/sed -E \
        "s/$key[[:space:]]*=[[:space:]]*(true|false)[[:space:]]*;/$key = $val;/"
    elif [ "$content" = "{}" ] || [ -z "$(echo "$content" | tr -d '[:space:]')" ]; then
      printf '{\n  %s = %s;\n}\n' "$key" "$val"
    else
      printf '%s\n' "$content" | ${pkgs.gnused}/bin/sed "\$ i\\  $key = $val;"
    fi
  }

  if [ -n "$SET_DANGER" ]; then
    ncc=$(ncc_read_module_config "core/management/nixos-control-center" 2>/dev/null || echo "{}")
    ncc=$(set_bool_key "$ncc" "dangerousIgnore" "$SET_DANGER")
    ncc_write_module_config "core/management/nixos-control-center" "$ncc"
    ${ui.messages.success "dangerousIgnore = $SET_DANGER (nixos-control-center)"}
  fi

  if [ -n "$SET_AUTO" ]; then
    sm=$(ncc_read_module_config "core/management/system-manager" 2>/dev/null || echo "{}")
    if echo "$sm" | grep -qE 'auto-build[[:space:]]*='; then
      sm=$(printf '%s\n' "$sm" | ${pkgs.gnused}/bin/sed -E \
        "s/auto-build[[:space:]]*=[[:space:]]*(true|false)[[:space:]]*;/autoBuild = $SET_AUTO;/")
    fi
    sm=$(set_bool_key "$sm" "autoBuild" "$SET_AUTO")
    ncc_write_module_config "core/management/system-manager" "$sm"
    ${ui.messages.success "autoBuild = $SET_AUTO (system-manager)"}
  fi

  if [ "$DO_REBUILD" = true ]; then
    host=$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo nixos)
    ${ui.messages.loading "Building with new host policy…"}
    exec env NCC_CLI_NESTED=1 ncc system build switch --flake "$NIXOS_DIR#$host"
  else
    if [ -z "''${NCC_CLI_NESTED:-}" ]; then
      ${ui.messages.info "Next: sudo ncc system build switch"}
      ${ui.messages.info "Or:    sudo ncc system host-policy … --rebuild"}
    fi
  fi
''
