{ pkgs, getModuleApi }:

let
  catalogFile = import ../lib/mk-catalog-json.nix { inherit pkgs; };
  ui = getModuleApi "cli-formatter";
  validator = ../lib/rice-validate.py;
  lua = pkgs.lua5_4 or pkgs.lua;
in
pkgs.writeShellScriptBin "ncc-hyprland-rice-validate" ''
  set -euo pipefail

  CATALOG_JSON="''${NCC_HYPRLAND_CATALOG:-${catalogFile}}"
  VALIDATOR=${pkgs.writeShellScriptBin "ncc-rice-validate-py" ''
    exec ${pkgs.python3}/bin/python3 ${validator} "$@"
  ''}/bin/ncc-rice-validate-py

  usage() {
    cat <<EOF
ncc hyprland rice validate — HARD 100% gate before apply (no host writes)

Exit 0 only when validated100=YES (every gate passes).
Anything soft / missing deps / verify-config fail → REJECTED (exit 1).

Usage:
  ncc hyprland rice validate <rice-id>
  ncc hyprland rice validate <rice-id> --json

Gates: clone, discover config, NCC deploy layout, hyprland --verify-config,
Lua require + luac, all exec binaries on PATH, no /home/ hardcodes.
Flake rices are always rejected (cannot prove host flake patch dry-run).
EOF
  }

  JSON=false
  RICE_ID=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) JSON=true; shift ;;
      --help|-h) usage; exit 0 ;;
      *) RICE_ID="$1"; shift ;;
    esac
  done

  if [[ -z "$RICE_ID" ]]; then
    usage >&2
    exit 2
  fi

  # Enrich validate PATH with common tools so absolute nix-store paths rewritten to basenames resolve.
  PATH=${pkgs.wl-clipboard}/bin:${pkgs.hyprland}/bin:${pkgs.coreutils}/bin:${pkgs.findutils}/bin:${pkgs.gnugrep}/bin:${pkgs.gnused}/bin:$PATH
  export PATH

  args=(
    --catalog "$CATALOG_JSON"
    --hyprland ${pkgs.hyprland}/bin/hyprland
    --luac ${lua}/bin/luac
    "$RICE_ID"
  )
  if [[ "$JSON" == true ]]; then
    args+=(--json)
  fi

  if ! "$VALIDATOR" "''${args[@]}"; then
    if [[ "$JSON" != true ]]; then
      ${ui.messages.error "REJECTED — not validated 100%. Apply blocked."}
      ${ui.messages.info "Next: fix missing deps / pick another rice / keep as preview-only"}
    fi
    exit 1
  fi

  if [[ "$JSON" != true ]]; then
    ${ui.messages.success "VALIDATED 100% — apply allowed for this rice"}
  fi
''
