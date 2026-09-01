{ pkgs, getModuleApi }:

let
  catalogFile = import ../lib/mk-catalog-json.nix { inherit pkgs; };
  ui = getModuleApi "cli-formatter";
in
pkgs.writeShellScriptBin "ncc-hyprland" ''
  set -euo pipefail

  CATALOG_JSON="''${NCC_HYPRLAND_CATALOG:-${catalogFile}}"
  JQ=${pkgs.jq}/bin/jq

  usage() {
    cat <<EOF
ncc hyprland — Hyprland rice catalog and wallpaper helpers

Usage:
  ncc hyprland status
  ncc hyprland rice list [--all]
  ncc hyprland rice info <id>
  ncc hyprland wallpaper list

Store lists one-click applyable rices only (wallpaper or flake preset).
Use rice list --all to include reference-only catalog entries.

Catalog source: Hyprland Hall of Fame (https://hypr.land/hall_of_fame/)
Apply via: ncc hyprland --gui  or  sudo ncc hyprland set rice=<id>

Examples:
  ncc hyprland rice list
  ncc hyprland rice info celestial
  ncc hyprland wallpaper list
EOF
  }

  rice_list() {
    local mode="store"
    if [[ "''${1:-}" == "--all" ]]; then
      mode="all"
      shift
    fi
    echo "id	name	creator	contest	rank	apply	applyable"
    if [[ "$mode" == "all" ]]; then
      "$JQ" -r '.rices[] | [
        .id,
        .name,
        .creator,
        (.contest | tostring),
        (.rank | tostring),
        (.applyMethod // "reference"),
        (if .applyable then "yes" else "no" end)
      ] | @tsv' "$CATALOG_JSON"
    else
      "$JQ" -r '.storeRices[] | [
        .id,
        .name,
        .creator,
        (.contest | tostring),
        (.rank | tostring),
        (.applyMethod // "wallpaper"),
        "yes"
      ] | @tsv' "$CATALOG_JSON"
    fi
  }

  rice_info() {
    local id="''${1:-}"
    if [[ -z "$id" ]]; then
      ${ui.messages.error "Missing rice id"}
      ${ui.messages.info "Next: ncc hyprland rice list"}
      exit 2
    fi
    if ! "$JQ" -e --arg id "$id" '.rices[] | select(.id == $id)' "$CATALOG_JSON" >/dev/null; then
      ${ui.messages.error "Unknown rice: $id"}
      ${ui.messages.info "Next: ncc hyprland rice list"}
      exit 1
    fi
    "$JQ" -r --arg id "$id" '
      .rices[] | select(.id == $id) |
      "id: \(.id)\nname: \(.name)\ncreator: \(.creator)\ncontest: #\(.contest) (\(.theme))\nrank: #\(.rank)\napply: \(.applyMethod // "reference") (\(.applyLabel // ""))\napplyable: \(if .applyable then "yes" else "no" end)\ndotfiles: \(.dotfilesUrl // "—")\nflake: \(if .flake then .flake.url else "—" end)\nthumbnail: \(.thumbnailUrl // "—")\nwallpaper-bundled: \(if .thumbnailHash != null then "yes" else "no" end)\ndescription: \(.description // "")"
    ' "$CATALOG_JSON"
  }

  wallpaper_list() {
    echo "id	name	apply"
    "$JQ" -r '.storeRices[] | select(.thumbnailHash != null) | [.id, .name, (.applyLabel // .applyMethod)] | @tsv' "$CATALOG_JSON"
  }

  status() {
    cat <<EOF
catalog=$(basename "$CATALOG_JSON")
rices=$("$JQ" -r '.riceIds | length' "$CATALOG_JSON")
store=$("$JQ" -r '.storeRices | length' "$CATALOG_JSON")
wallpapers=$("$JQ" -r '[.storeRices[] | select(.thumbnailHash != null)] | length' "$CATALOG_JSON")
source=https://hypr.land/hall_of_fame/
EOF
  }

  case "''${1:-}" in
    ""|help|-h|--help) usage ;;
    catalog) shift; status "$@" ;;
    status) shift; status "$@" ;;
    rice)
      shift
      case "''${1:-}" in
        list) shift; rice_list "$@" ;;
        info) shift; rice_info "''${1:-}" ;;
        *)
          ${ui.messages.error ''Unknown: ncc hyprland rice ''${1:-}''}
          ${ui.messages.info "Next: ncc hyprland rice list"}
          exit 2
          ;;
      esac
      ;;
    wallpaper)
      shift
      case "''${1:-}" in
        list) wallpaper_list ;;
        *)
          ${ui.messages.error ''Unknown: ncc hyprland wallpaper ''${1:-}''}
          ${ui.messages.info "Next: ncc hyprland wallpaper list"}
          exit 2
          ;;
      esac
      ;;
    *)
      ${ui.messages.error ''Unknown: ncc hyprland ''${1:-}''}
      ${ui.messages.info "Next: ncc hyprland --help"}
      exit 2
      ;;
  esac
''
