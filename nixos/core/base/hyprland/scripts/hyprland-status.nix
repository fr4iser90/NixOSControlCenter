{ pkgs, getModuleApi, getModuleMetadata, getModuleConfig, moduleName }:

let
  paths = import ../lib/paths.nix;
  catalog = import ../lib/rice-catalog.nix;
  catalogCount = builtins.length (builtins.attrNames catalog);
in
pkgs.writeShellScriptBin "ncc-hyprland-status" ''
  set -euo pipefail
  NIXOS_DIR="''${NIXOS_DIR:-/etc/nixos}"
  ${(import "${(getModuleMetadata "system-manager").path}/lib/config-facade.nix" { inherit pkgs; }).sourcePreamble { nixosRoot = "/etc/nixos"; }}

  CURRENT=$(ncc_read_module_config "core/base/hyprland" 2>/dev/null || echo "{}")
  JSON=$(${pkgs.nix}/bin/nix-instantiate --eval --strict --json -E "$CURRENT" 2>/dev/null || echo "{}")

  enable=$(echo "$JSON" | ${pkgs.jq}/bin/jq -r 'if .enable == true then "true" else "false" end')
  rice=$(echo "$JSON" | ${pkgs.jq}/bin/jq -r 'if .rice == null then "null" else .rice end')
  wallpaper_rice=$(echo "$JSON" | ${pkgs.jq}/bin/jq -r 'if .wallpaper.rice == null then "null" else .wallpaper.rice end')
  wallpaper_path=$(echo "$JSON" | ${pkgs.jq}/bin/jq -r 'if .wallpaper.path == null then "null" else .wallpaper.path end')

  collection_installed=false
  collection_method=
  collection_hypr=
  if [[ -f "${paths.activeManifest}" ]]; then
    collection_installed=true
    collection_method=$(${pkgs.jq}/bin/jq -r '.applyMethod // ""' "${paths.activeManifest}")
    collection_hypr=$(${pkgs.jq}/bin/jq -r '.hyprConfig // ""' "${paths.activeManifest}")
  fi

  cat <<EOF
enable=$enable
rice=$rice
wallpaper.rice=$wallpaper_rice
wallpaper.path=$wallpaper_path
catalog_rices=${toString catalogCount}
collection.installed=$collection_installed
collection.method=$collection_method
collection.hyprConfig=$collection_hypr
collections.root=${paths.collectionsRoot}
EOF
''
