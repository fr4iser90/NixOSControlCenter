{ pkgs, getModuleApi, getModuleMetadata, getModuleConfig, moduleName, ... }:

let
  ui = getModuleApi "cli-formatter";
  facade = import "${(getModuleMetadata "system-manager").path}/lib/config-facade.nix" {
    inherit pkgs;
  };
  cfg = getModuleConfig moduleName;

  defEnable = if cfg.enable or true then "true" else "false";
  defEnv = cfg.environment or "plasma";
  defMgr = cfg.display.manager or "sddm";
  defServer = cfg.display.server or "wayland";
  defSession = cfg.display.session or "plasma";
  defDark = if cfg.theme.dark or true then "true" else "false";
in
pkgs.writeShellScriptBin "ncc-desktop-set" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail

  NIXOS_DIR="''${NIXOS_DIR:-/etc/nixos}"
  ${facade.sourcePreamble { nixosRoot = "/etc/nixos"; }}
  export NIXOS_ROOT="$NIXOS_DIR"
  export CONFIGS_BASE="$NIXOS_DIR/systemConfig"
  export MONOLITH_FILE="$NIXOS_DIR/systemConfig.nix"

  DO_REBUILD=false
  ENABLE="${defEnable}"
  ENVIRONMENT="${defEnv}"
  MANAGER="${defMgr}"
  SERVER="${defServer}"
  SESSION="${defSession}"
  DARK="${defDark}"
  PINNED_APPS="[]"
  PINNED_AUTO="true"
  PINNED_FORCE="false"
  SESSION_EXPLICIT=false

  usage() {
    cat <<EOF
ncc desktop set — write desktop settings to systemConfig

Usage:
  sudo ncc desktop set [options] [key=value …]

Keys:
  enable=true|false
  environment=plasma|gnome|xfce
  display.manager=sddm|gdm|lightdm   (also: manager=…)
  display.server=wayland|x11|hybrid  (also: server=…)
  display.session=<name>             (also: session=…; default follows environment)
  theme.dark=true|false              (also: dark=…)

Options:
  --rebuild, -r   After writing: ncc system build switch
  --help, -h

Examples:
  sudo ncc desktop set environment=plasma manager=sddm server=wayland dark=true
  sudo ncc desktop set environment=gnome manager=gdm --rebuild
EOF
  }

  CURRENT=$(ncc_read_module_config "core/base/desktop" 2>/dev/null || echo "{}")
  if [[ "$CURRENT" != "{}" && -n "$(echo "$CURRENT" | tr -d '[:space:]')" ]]; then
    JSON=$(${pkgs.nix}/bin/nix-instantiate --eval --strict --json -E "$CURRENT" 2>/dev/null || echo "")
    if [[ -n "$JSON" && "$JSON" != "null" ]]; then
      ENABLE=$(echo "$JSON" | ${pkgs.jq}/bin/jq -r 'if .enable == false then "false" else "true" end')
      ENVIRONMENT=$(echo "$JSON" | ${pkgs.jq}/bin/jq -r --arg d "${defEnv}" '.environment // $d')
      MANAGER=$(echo "$JSON" | ${pkgs.jq}/bin/jq -r --arg d "${defMgr}" '.display.manager // $d')
      SERVER=$(echo "$JSON" | ${pkgs.jq}/bin/jq -r --arg d "${defServer}" '.display.server // $d')
      SESSION=$(echo "$JSON" | ${pkgs.jq}/bin/jq -r --arg d "${defSession}" '.display.session // $d')
      DARK=$(echo "$JSON" | ${pkgs.jq}/bin/jq -r 'if .theme.dark == false then "false" else "true" end')
      PINNED_AUTO=$(echo "$JSON" | ${pkgs.jq}/bin/jq -r 'if .pinnedAppsAuto == false then "false" else "true" end')
      PINNED_FORCE=$(echo "$JSON" | ${pkgs.jq}/bin/jq -r 'if .pinnedAppsForce == true then "true" else "false" end')
      PINNED_APPS=$(echo "$JSON" | ${pkgs.jq}/bin/jq -c '.pinnedApps // []')
    fi
  fi

  for arg in "$@"; do
    case "$arg" in
      --rebuild|-r) DO_REBUILD=true ;;
      --help|-h) usage; exit 0 ;;
      enable=true|enable=false) ENABLE="''${arg#enable=}" ;;
      environment=*)
        ENVIRONMENT="''${arg#environment=}"
        if [[ "$SESSION_EXPLICIT" != true ]]; then
          SESSION="$ENVIRONMENT"
        fi
        ;;
      display.manager=*) MANAGER="''${arg#display.manager=}" ;;
      manager=*) MANAGER="''${arg#manager=}" ;;
      display.server=*) SERVER="''${arg#display.server=}" ;;
      server=*) SERVER="''${arg#server=}" ;;
      display.session=*)
        SESSION_EXPLICIT=true
        SESSION="''${arg#display.session=}"
        ;;
      session=*)
        SESSION_EXPLICIT=true
        SESSION="''${arg#session=}"
        ;;
      theme.dark=*) DARK="''${arg#theme.dark=}" ;;
      dark=*) DARK="''${arg#dark=}" ;;
      *)
        ${ui.messages.error "Unknown argument: $arg"}
        usage >&2
        exit 2
        ;;
    esac
  done

  case "$ENVIRONMENT" in plasma|gnome|xfce) ;; *)
    ${ui.messages.error "Invalid environment: $ENVIRONMENT (plasma|gnome|xfce)"}
    exit 2
  esac
  case "$MANAGER" in sddm|gdm|lightdm) ;; *)
    ${ui.messages.error "Invalid display.manager: $MANAGER (sddm|gdm|lightdm)"}
    exit 2
  esac
  case "$SERVER" in wayland|x11|hybrid) ;; *)
    ${ui.messages.error "Invalid display.server: $SERVER (wayland|x11|hybrid)"}
    exit 2
  esac
  case "$DARK" in true|false) ;; *)
    ${ui.messages.error "Invalid theme.dark: $DARK (true|false)"}
    exit 2
  esac
  case "$ENABLE" in true|false) ;; *)
    ${ui.messages.error "Invalid enable: $ENABLE"}
    exit 2
  esac

  if [ "''${EUID:-$(id -u)}" -ne 0 ]; then
    ${ui.messages.error "Run as root: sudo ncc desktop set …"}
    exit 1
  fi

  PINNED_NIX=$(echo "''${PINNED_APPS:-[]}" | ${pkgs.jq}/bin/jq -r '
    if type != "array" then "[]"
    elif length == 0 then "[]"
    else "[" + (map("\"" + gsub("\""; "") + "\"") | join(" ")) + "]"
    end
  ')

  CONTENT=$(cat <<EOF
{
  enable = $ENABLE;
  environment = "$ENVIRONMENT";
  display = {
    manager = "$MANAGER";
    server = "$SERVER";
    session = "$SESSION";
  };
  theme = {
    dark = $DARK;
  };
  pinnedApps = $PINNED_NIX;
  pinnedAppsAuto = $PINNED_AUTO;
  pinnedAppsForce = $PINNED_FORCE;
}
EOF
)

  ncc_write_module_config "core/base/desktop" "$CONTENT"
  ${ui.messages.success "Desktop settings written to systemConfig"}
  ${ui.tables.keyValue "environment" "$ENVIRONMENT"}
  ${ui.tables.keyValue "display.manager" "$MANAGER"}
  ${ui.tables.keyValue "display.server" "$SERVER"}
  ${ui.tables.keyValue "display.session" "$SESSION"}
  ${ui.tables.keyValue "theme.dark" "$DARK"}
  ${ui.messages.warning "DE / login / display-server changes need rebuild + re-login (or reboot) to fully apply."}

  if [ "$DO_REBUILD" = true ]; then
    host=$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo nixos)
    ${ui.messages.loading "Building new configuration…"}
    exec ncc system build switch --flake "$NIXOS_DIR#$host"
  else
    ${ui.messages.info "Next: sudo ncc system build switch"}
    ${ui.messages.info "Or:    sudo ncc desktop set … --rebuild"}
  fi
''
