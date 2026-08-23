# Discover and apply migrations under <module>/migrations/v*-to-v*.nix.
# Paths in removeRelativePaths are relative to that module root — never hardcode modules here.
#
# Used by:
#   - ncc-module-migrate (runner.nix)
#   - ncc system-update post-sync (before rebuild)
{ pkgs }:

pkgs.writeShellScriptBin "ncc-apply-migrations" ''
  set -euo pipefail

  NIXOS_ROOT="''${1:-/etc/nixos}"
  DRY="''${2:-0}"
  STATE_FILE="''${3:-/var/lib/ncc/module-migrations.json}"

  command -v nix-instantiate >/dev/null 2>&1 || exit 0
  command -v ${pkgs.jq}/bin/jq >/dev/null 2>&1 || exit 0

  if [[ -f "$STATE_FILE" ]]; then
    APPLIED=$(${pkgs.jq}/bin/jq -c '.applied // []' "$STATE_FILE" 2>/dev/null || echo '[]')
  else
    APPLIED='[]'
  fi

  already_applied() {
    local id="$1"
    echo "$APPLIED" | ${pkgs.jq}/bin/jq -e --arg id "$id" 'index($id) != null' >/dev/null 2>&1
  }

  mark_applied() {
    local id="$1"
    local tmp
    tmp=$(mktemp)
    APPLIED=$(echo "$APPLIED" | ${pkgs.jq}/bin/jq -c --arg id "$id" '
      . as $a | if ($a | index($id)) then $a else ($a + [$id]) end
    ')
    ${pkgs.jq}/bin/jq -n --argjson applied "$APPLIED" \
      '{applied: $applied, updated: (now | todate)}' >"$tmp"
    if [[ "$DRY" == "1" ]]; then
      rm -f "$tmp"
      return 0
    fi
    if [[ "''${EUID:-$(id -u)}" -ne 0 ]]; then
      rm -f "$tmp"
      return 1
    fi
    mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true
    cp "$tmp" "$STATE_FILE"
    chmod 644 "$STATE_FILE" 2>/dev/null || true
    rm -f "$tmp"
  }

  # Walk core/ + modules/ for module-owned migrations (not config-schema migrations).
  while IFS= read -r -d ''' mig_file; do
    [[ -n "$mig_file" ]] || continue
    # …/<module>/migrations/vX-to-vY.nix → module root is parent of migrations/
    mig_dir=$(dirname "$mig_file")
    module_root=$(dirname "$mig_dir")
    # Skip system-manager config-schema migrations tree
    case "$mig_file" in
      */config-migration/*|*/config-schema/*) continue ;;
    esac

    meta_json=$(nix-instantiate --eval --strict --json -E "
      let
        lib = (import <nixpkgs> {}).lib;
        m = import $mig_file { inherit lib; };
        id = m.id or \"\";
        paths = m.removeRelativePaths or [];
      in { inherit id paths; }
    " 2>/dev/null) || continue

    id=$(echo "$meta_json" | ${pkgs.jq}/bin/jq -r '.id // empty')
    [[ -n "$id" ]] || id="$(basename "$module_root")-$(basename "$mig_file" .nix)"

    need=0
    while IFS= read -r rel; do
      [[ -z "$rel" || "$rel" == "null" ]] && continue
      [[ -e "$module_root/$rel" ]] && need=1
    done < <(echo "$meta_json" | ${pkgs.jq}/bin/jq -r '.paths[]?')

    if [[ "$need" -eq 0 ]]; then
      already_applied "$id" || mark_applied "$id" || true
      continue
    fi

    if already_applied "$id"; then
      echo "Re-applying migration $id (stale paths still present)" >&2
    else
      echo "Applying migration $id" >&2
    fi

    while IFS= read -r rel; do
      [[ -z "$rel" || "$rel" == "null" ]] && continue
      target="$module_root/$rel"
      [[ -e "$target" ]] || continue
      if [[ "$DRY" == "1" ]]; then
        echo "  dry-run: would remove $target" >&2
        continue
      fi
      echo "  removing: ''${target#"$NIXOS_ROOT"/}" >&2
      rm -rf "$target" 2>/dev/null || sudo rm -rf "$target"
    done < <(echo "$meta_json" | ${pkgs.jq}/bin/jq -r '.paths[]?')

    if [[ "$DRY" != "1" ]]; then
      mark_applied "$id" || exit 1
    fi
  done < <(
    find "$NIXOS_ROOT/core" "$NIXOS_ROOT/modules" \
      -type f -path '*/migrations/v*-to-v*.nix' -print0 2>/dev/null || true
  )
''
