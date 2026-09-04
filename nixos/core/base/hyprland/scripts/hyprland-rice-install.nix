{ pkgs, getModuleApi, getModuleMetadata, getModuleConfig, moduleName, ... }:

let
  ui = getModuleApi "cli-formatter";
  facade = import "${(getModuleMetadata "system-manager").path}/lib/config-facade.nix" {
    inherit pkgs;
  };
  catalogFile = import ../lib/mk-catalog-json.nix { inherit pkgs; };
  paths = import ../lib/paths.nix;
  flakePatch = ../lib/flake-rice-patch.py;
  flakePatchBin = pkgs.writeShellScriptBin "ncc-flake-rice-patch" ''
    exec ${pkgs.python3}/bin/python3 ${flakePatch} "$@"
  '';
  riceSanitize = ../lib/rice-sanitize.py;
  riceSanitizeBin = pkgs.writeShellScriptBin "ncc-rice-sanitize" ''
    exec ${pkgs.python3}/bin/python3 ${riceSanitize} "$@"
  '';
  hyprlandBin = "${pkgs.hyprland}/bin/hyprland";
in
pkgs.writeShellScriptBin "ncc-hyprland-rice-install" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail

  CATALOG_JSON="''${NCC_HYPRLAND_CATALOG:-${catalogFile}}"
  JQ=${pkgs.jq}/bin/jq
  GIT=${pkgs.git}/bin/git
  RSYNC=${pkgs.rsync}/bin/rsync
  SANITIZE=${riceSanitizeBin}/bin/ncc-rice-sanitize
  HYPRLAND_BIN=${hyprlandBin}
  NIXOS_DIR="''${NIXOS_DIR:-/etc/nixos}"
  ${facade.sourcePreamble { nixosRoot = "/etc/nixos"; }}
  export NIXOS_ROOT="$NIXOS_DIR"
  STATE_ROOT="${paths.stateRoot}"
  COLLECTIONS_ROOT="${paths.collectionsRoot}"
  ACTIVE_MANIFEST="${paths.activeManifest}"
  FLAKE_PATCH=${flakePatchBin}/bin/ncc-flake-rice-patch

  usage() {
    cat <<EOF
ncc hyprland rice install — fetch collection + patch flake for active rice

Usage:
  sudo ncc hyprland rice install <rice-id>
  sudo ncc hyprland rice install --from-set

Reads rice id from args or current systemConfig when --from-set.
EOF
  }

  rice_json() {
    local id="$1"
    "$JQ" -c --arg id "$id" '.rices[] | select(.id == $id)' "$CATALOG_JSON"
  }

  discover_hypr_config() {
    local root="$1"
    local json="$2"
    local c path found
    while IFS= read -r c; do
      [[ -z "$c" ]] && continue
      path="$root/upstream/$c"
      if [[ -f "$path" ]]; then
        echo "$c"
        return 0
      fi
    done < <("$JQ" -r '.dotfiles.hyprCandidates[]? // empty' <<< "$json")
    found=$(
      find "$root/upstream" -type f \( -name 'hyprland.conf' -o -name 'hyprland.lua' \) 2>/dev/null \
        | LC_ALL=C sort \
        | head -n 1
    ) || true
    if [[ -n "''${found:-}" ]]; then
      echo "''${found#$root/upstream/}"
      return 0
    fi
  }

  fetch_dotfiles() {
    local id="$1"
    local json="$2"
    local clone_url ref dest tmp
    clone_url=$("$JQ" -r '.dotfiles.cloneUrl // ""' <<< "$json")
    ref=$("$JQ" -r '.dotfiles.ref // "main"' <<< "$json")
    if [[ -z "$clone_url" ]]; then
      ${ui.messages.error "No dotfiles clone URL for $id"}
      return 1
    fi
    dest="$COLLECTIONS_ROOT/$id"
    tmp=$(mktemp -d)
    mkdir -p "$dest"
    ${ui.messages.loading "Fetching dotfiles for $id…"}
    if ! "$GIT" clone --depth 1 --branch "$ref" "$clone_url" "$tmp/upstream" 2>/dev/null; then
      rm -rf "$tmp"
      if ! "$GIT" clone --depth 1 "$clone_url" "$tmp/upstream"; then
        ${ui.messages.error "git clone failed: $clone_url"}
        return 1
      fi
    fi
    mkdir -p "$dest/upstream"
    "$RSYNC" -a --delete "$tmp/upstream/" "$dest/upstream/"
    rm -rf "$tmp"
    ${ui.messages.loading "Sanitizing upstream paths for NCC…"}
    "$SANITIZE" "$dest/upstream" || true
    local hypr_rel
    hypr_rel=$(discover_hypr_config "$dest" "$json") || true
    if [[ -z "''${hypr_rel:-}" ]]; then
      ${ui.messages.error "No hyprland.conf / hyprland.lua found in upstream repo for $id"}
      ${ui.messages.info "Tried catalog hyprCandidates and a repo-wide search"}
      return 1
    fi
    ${ui.messages.loading "Repairing config for current Hyprland (verify-config)…"}
    if ! "$SANITIZE" "$dest/upstream" --hyprland "$HYPRLAND_BIN" --entry "$dest/upstream/$hypr_rel"; then
      ${ui.messages.error "hyprland --verify-config still failing after sanitize — rice not installable"}
      return 1
    fi
    "$JQ" -n \
      --arg id "$id" \
      --arg method "$("$JQ" -r '.applyMethod' <<< "$json")" \
      --arg collectionDir "$dest" \
      --arg hyprConfig "$hypr_rel" \
      --arg cloneUrl "$clone_url" \
      --arg ref "$ref" \
      --arg fetchedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      '{
        rice: $id,
        applyMethod: $method,
        collectionDir: $collectionDir,
        hyprConfig: $hyprConfig,
        dotfiles: { cloneUrl: $cloneUrl, ref: $ref },
        fetchedAt: $fetchedAt
      }' > "$dest/manifest.json"
    echo "$hypr_rel"
  }

  patch_flake() {
    local id="$1"
    local json="$2"
    local method
    method=$("$JQ" -r '.applyMethod' <<< "$json")
    if [[ "$method" != "flake" ]]; then
      # Clear flake rice markers when switching to dotfiles-only rice
      "$FLAKE_PATCH" "$NIXOS_DIR/flake.nix" --rice-id "" --input-name "" --flake-url ""
      return 0
    fi
    local input_name flake_url flake_ref nixos_module
    input_name=$("$JQ" -r '.flake.inputName // ""' <<< "$json")
    flake_url=$("$JQ" -r '.flake.url // ""' <<< "$json")
    flake_ref=$("$JQ" -r '.flake.ref // "master"' <<< "$json")
    nixos_module=$("$JQ" -r '.flake.nixosModule // "nixosModules.default"' <<< "$json")
    if [[ -z "$input_name" || -z "$flake_url" ]]; then
      ${ui.messages.error "Flake metadata missing for $id"}
      return 1
    fi
    ${ui.messages.loading "Patching flake.nix for $input_name…"}
    "$FLAKE_PATCH" "$NIXOS_DIR/flake.nix" \
      --rice-id "$id" \
      --input-name "$input_name" \
      --flake-url "$flake_url" \
      --flake-ref "$flake_ref" \
      --nixos-module "$nixos_module"
    if command -v nix >/dev/null 2>&1; then
      nix flake lock --flake "$NIXOS_DIR" 2>/dev/null || true
    fi
  }

  write_active_manifest() {
    local id="$1"
    local json="$2"
    local dest="$COLLECTIONS_ROOT/$id"
    mkdir -p "$STATE_ROOT"
    "$JQ" -n \
      --arg id "$id" \
      --arg method "$("$JQ" -r '.applyMethod' <<< "$json")" \
      --arg collectionDir "$dest" \
      --arg hyprConfig "$(cat "$dest/manifest.json" | "$JQ" -r '.hyprConfig')" \
      --arg hyprDest "${paths.hyprConfigDest}" \
      '{
        rice: $id,
        applyMethod: $method,
        collectionDir: $collectionDir,
        hyprConfig: $hyprConfig,
        hyprDest: $hyprDest
      }' > "$ACTIVE_MANIFEST"
  }

  install_rice() {
    local id="$1"
    local json
    json=$(rice_json "$id") || true
    if [[ -z "''${json:-}" ]]; then
      ${ui.messages.error "Unknown rice id: $id"}
      exit 1
    fi
    local applyable
    applyable=$("$JQ" -r '.applyable' <<< "$json")
    if [[ "$applyable" != "true" ]]; then
      ${ui.messages.error "Rice is not installable: $id"}
      exit 1
    fi
    local method
    method=$("$JQ" -r '.applyMethod' <<< "$json")
    mkdir -p "$COLLECTIONS_ROOT"
    if [[ "$method" == "dotfiles" || "$method" == "flake" ]]; then
      fetch_dotfiles "$id" "$json"
      patch_flake "$id" "$json"
      write_active_manifest "$id" "$json"
    elif [[ "$method" == "wallpaper" ]]; then
      "$FLAKE_PATCH" "$NIXOS_DIR/flake.nix" --rice-id "" --input-name "" --flake-url ""
      mkdir -p "$STATE_ROOT"
      "$JQ" -n --arg id "$id" --arg method "$method" \
        '{ rice: $id, applyMethod: $method, collectionDir: null, hyprConfig: null }' \
        > "$ACTIVE_MANIFEST"
    else
      ${ui.messages.error "Reference-only rice: $id"}
      exit 1
    fi
    ${ui.messages.success "Installed rice collection: $id ($method)"}
  }

  RICE_ID=""
  FROM_SET=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from-set) FROM_SET=true; shift ;;
      --help|-h) usage; exit 0 ;;
      *) RICE_ID="$1"; shift ;;
    esac
  done

  if [[ "$FROM_SET" == true && -z "$RICE_ID" ]]; then
    CURRENT=$(ncc_read_module_config "core/base/hyprland" 2>/dev/null || echo "{}")
    RICE_ID=$(${pkgs.nix}/bin/nix-instantiate --eval --strict --json -E "$CURRENT" 2>/dev/null \
      | "$JQ" -r '.rice // empty')
    if [[ -z "$RICE_ID" || "$RICE_ID" == "null" ]]; then
      ${ui.messages.error "No active rice in systemConfig"}
      exit 1
    fi
  fi

  if [[ -z "$RICE_ID" ]]; then
    usage >&2
    exit 2
  fi

  if [[ "''${EUID:-$(id -u)}" -ne 0 ]]; then
    ${ui.messages.error "Run as root: sudo ncc hyprland rice install …"}
    exit 1
  fi

  install_rice "$RICE_ID"
''
