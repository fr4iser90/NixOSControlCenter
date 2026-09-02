{ pkgs, getModuleApi, getModuleMetadata, getModuleConfig, moduleName, ... }:

let
  ui = getModuleApi "cli-formatter";
  facade = import "${(getModuleMetadata "system-manager").path}/lib/config-facade.nix" {
    inherit pkgs;
  };
  cfg = getModuleConfig moduleName;
  catalog = import ../lib/rice-catalog.nix { inherit pkgs; };
  riceIds = builtins.attrNames catalog;
  riceIdsList = builtins.concatStringsSep " " riceIds;
  isApplyable = rice:
    let method = rice.applyMethod or "reference";
    in (method == "dotfiles" && (rice.dotfiles.cloneUrl or "") != "")
      || (method == "flake" && rice ? flake && (rice.flake.url or "") != "")
      || (method == "wallpaper" && rice.thumbnailHash != null);
  applyableIds = builtins.filter (id: isApplyable catalog.${id}) riceIds;
  applyableIdsList = builtins.concatStringsSep " " applyableIds;

  riceInstall = import ./hyprland-rice-install.nix {
    inherit pkgs getModuleApi getModuleMetadata getModuleConfig moduleName;
  };
  riceValidate = import ./hyprland-rice-validate.nix {
    inherit pkgs getModuleApi;
  };

  nixNullStr = v: if v == null then "null" else v;

  defEnable = if cfg.enable or false then "true" else "false";
  defRice = nixNullStr (cfg.rice or null);
  defWallRice = nixNullStr (cfg.wallpaper.rice or null);
  defWallPath = nixNullStr (cfg.wallpaper.path or null);
in
pkgs.writeShellScriptBin "ncc-hyprland-set" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail

  NIXOS_DIR="''${NIXOS_DIR:-/etc/nixos}"
  ${facade.sourcePreamble { nixosRoot = "/etc/nixos"; }}
  export NIXOS_ROOT="$NIXOS_DIR"
  export CONFIGS_BASE="$NIXOS_DIR/systemConfig"
  export MONOLITH_FILE="$NIXOS_DIR/systemConfig.nix"

  DO_REBUILD=false
  DRY_RUN=false
  ENABLE="${defEnable}"
  RICE="${defRice}"
  WALL_RICE="${defWallRice}"
  WALL_PATH="${defWallPath}"

  usage() {
    cat <<EOF
ncc hyprland set — write hyprland rice/wallpaper to systemConfig

Usage:
  sudo ncc hyprland set [options] [key=value …]

Keys:
  enable=true|false
  rice=<id>|null
  wallpaper.rice=<id>|null
  wallpaper.path=<absolute-path>|null

Options:
  --rebuild, -r   After writing: ncc system build switch
  --dry-run, -d   Preview only
  --help, -h

Examples:
  sudo ncc hyprland set enable=true rice=celestial
  sudo ncc hyprland set wallpaper.rice=astroland
  sudo ncc hyprland set rice=null wallpaper.path=/home/user/Pictures/wall.png
EOF
  }

  CURRENT=$(ncc_read_module_config "core/base/hyprland" 2>/dev/null || echo "{}")
  if [[ "$CURRENT" != "{}" && -n "$(echo "$CURRENT" | tr -d '[:space:]')" ]]; then
    JSON=$(${pkgs.nix}/bin/nix-instantiate --eval --strict --json -E "$CURRENT" 2>/dev/null || echo "")
    if [[ -n "$JSON" && "$JSON" != "null" ]]; then
      ENABLE=$(echo "$JSON" | ${pkgs.jq}/bin/jq -r 'if .enable == true then "true" else "false" end')
      RICE=$(echo "$JSON" | ${pkgs.jq}/bin/jq -r 'if .rice == null then "null" else .rice end')
      WALL_RICE=$(echo "$JSON" | ${pkgs.jq}/bin/jq -r 'if .wallpaper.rice == null then "null" else .wallpaper.rice end')
      WALL_PATH=$(echo "$JSON" | ${pkgs.jq}/bin/jq -r 'if .wallpaper.path == null then "null" else .wallpaper.path end')
    fi
  fi

  for arg in "$@"; do
    case "$arg" in
      --rebuild|-r) DO_REBUILD=true ;;
      --dry-run|-d) DRY_RUN=true ;;
      --help|-h) usage; exit 0 ;;
      enable=true|enable=false) ENABLE="''${arg#enable=}" ;;
      rice=*) RICE="''${arg#rice=}" ;;
      wallpaper.rice=*) WALL_RICE="''${arg#wallpaper.rice=}" ;;
      wallpaper.path=*) WALL_PATH="''${arg#wallpaper.path=}" ;;
      *)
        ${ui.messages.error "Unknown argument: $arg"}
        usage >&2
        exit 2
        ;;
    esac
  done

  case "$ENABLE" in true|false) ;; *)
    ${ui.messages.error "Invalid enable: $ENABLE"}
    exit 2
  esac

  validate_rice() {
    local val="$1" label="$2"
    local require_applyable="''${3:-false}"
    [[ "$val" == "null" || -z "$val" ]] && return 0
    if [[ "$val" == *' '* ]]; then
      ${ui.messages.error "Invalid $label: $val"}
      exit 2
    fi
    local ok=false
    for id in ${riceIdsList}; do
      [[ "$id" == "$val" ]] && ok=true
    done
    if [[ "$ok" != true ]]; then
      ${ui.messages.error "Unknown rice id for $label: $val"}
      ${ui.messages.info "Next: ncc hyprland rice list"}
      exit 2
    fi
    if [[ "$require_applyable" == "true" ]]; then
      local applyable=false
      for id in ${applyableIdsList}; do
        [[ "$id" == "$val" ]] && applyable=true
      done
      if [[ "$applyable" != true ]]; then
        ${ui.messages.error "Rice not in applyable store: $val"}
        ${ui.messages.info "Next: ncc hyprland rice list (or rice list --all for reference entries)"}
        exit 2
      fi
    fi
  }

  validate_rice "$RICE" "rice" "true"
  validate_rice "$WALL_RICE" "wallpaper.rice" "true"

  # HARD GATE: rice apply only when validated100
  if [[ "$RICE" != "null" && -n "$RICE" ]]; then
    ${ui.messages.loading "100% validating rice $RICE…"}
    if ! ${riceValidate}/bin/ncc-hyprland-rice-validate "$RICE"; then
      ${ui.messages.error "Apply blocked — rice $RICE is not validated 100%"}
      ${ui.messages.info "Next: ncc hyprland rice validate $RICE"}
      exit 1
    fi
  fi

  if [ "''${EUID:-$(id -u)}" -ne 0 ] && [ "$DRY_RUN" != true ]; then
    ${ui.messages.error "Run as root: sudo ncc hyprland set …"}
    exit 1
  fi

  rice_nix() {
    local v="$1"
    if [[ "$v" == "null" || -z "$v" ]]; then echo "null"; else echo "\"$v\""; fi
  }
  path_nix() {
    local v="$1"
    if [[ "$v" == "null" || -z "$v" ]]; then echo "null"; else echo "\"$v\""; fi
  }

  CONTENT=$(cat <<EOF
{
  enable = $( [[ "$ENABLE" == "true" ]] && echo true || echo false );
  rice = $(rice_nix "$RICE");
  wallpaper = {
    rice = $(rice_nix "$WALL_RICE");
    path = $(path_nix "$WALL_PATH");
  };
}
EOF
)

  if [[ "$DRY_RUN" == true ]]; then
    ${ui.text.header "Hyprland set (dry-run)"}
    printf '%s\n' "$CONTENT"
    exit 0
  fi

  ${ui.messages.loading "Writing hyprland settings…"}
  ncc_write_module_config "core/base/hyprland" "$CONTENT"

  if [[ "$RICE" != "null" && -n "$RICE" ]]; then
    ${ui.messages.loading "Installing rice collection…"}
    if ! ${riceInstall}/bin/ncc-hyprland-rice-install --from-set; then
      ${ui.messages.error "Rice install failed — systemConfig written; fix install then rebuild"}
      exit 1
    fi
  fi

  if [[ "$DO_REBUILD" == true ]]; then
    ${ui.messages.info "Rebuilding…"}
    exec ncc system build switch
  fi

  ${ui.messages.success "Hyprland settings written."}
  ${ui.messages.info "Next: ncc system build switch (or --rebuild)"}
''
