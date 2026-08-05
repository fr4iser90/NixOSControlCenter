#!/usr/bin/env bash
# Bump the *repo* NixOS stable pin (flake inputs + stateVersion + VM defaults).
# For live hosts prefer: sudo ncc system update-channels --bump-to YY.MM
# (that updates flake input URLs only; leaves host stateVersion alone).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../" && pwd)"
FLAKE_FILE="$REPO_ROOT/nixos/flake.nix"
DISTROS_FILE="$REPO_ROOT/nixos/modules/infrastructure/vm/lib/distros.nix"
USER_TEMPLATE="$REPO_ROOT/nixos/core/base/user/template-per-user-config.nix"

AUTO_YES=0
TARGET=""

while [ $# -gt 0 ]; do
  case "$1" in
    -y|--yes) AUTO_YES=1; shift ;;
    --to)
      TARGET="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: check-nixos-version.sh [--to YY.MM] [-y|--yes]"
      echo "  Updates repo flake pins, stateVersion, and VM ISO defaults."
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

echo "=== NixOS Version Check (repo) ==="
echo ""

if [ ! -f "$FLAKE_FILE" ]; then
  echo "Error: $FLAKE_FILE not found!"
  exit 1
fi

CURRENT=$(grep -E 'nixpkgs-stable\.url|nixos-[0-9]+\.[0-9]+' "$FLAKE_FILE" \
  | grep -oE 'nixos-[0-9]+\.[0-9]+' \
  | head -1 \
  | sed 's/nixos-//' || true)

if [ -z "${CURRENT:-}" ]; then
  echo "Error: Could not find current nixos-YY.MM pin in flake.nix"
  exit 1
fi

echo "Current repo pin: $CURRENT"

if [ -n "$TARGET" ]; then
  LATEST="$TARGET"
  echo "Target (forced): $LATEST"
else
  echo "Fetching latest stable nixos-* branch from GitHub..."
  API_URL="https://api.github.com/repos/NixOS/nixpkgs/git/matching-refs/heads/nixos-"
  RAW=$(curl -fsSL "$API_URL" 2>/dev/null || true)
  if [ -z "${RAW:-}" ]; then
    echo "Error: Failed to reach GitHub API"
    exit 1
  fi
  LATEST=$(echo "$RAW" | jq -r '
    [ .[]?.ref
      | sub("^refs/heads/nixos-"; "")
      | select(test("^[0-9]+\\.[0-9]+$"))
    ]
    | sort_by(split(".") | map(tonumber))
    | last // empty
  ')
  if [ -z "${LATEST:-}" ]; then
    echo "Error: Could not determine latest version"
    exit 1
  fi
  echo "Latest stable: $LATEST"
fi

echo ""

if [ "$CURRENT" = "$LATEST" ]; then
  echo "✓ Repo already on nixos-$CURRENT"
  exit 0
fi

echo "Update available: $CURRENT -> $LATEST"
echo ""
echo "This will update:"
echo "  - nixpkgs-stable:     nixos-$CURRENT -> nixos-$LATEST"
echo "  - home-manager-stable: release-$CURRENT -> release-$LATEST"
echo "  - nixosRelease / stateVersion: \"$CURRENT\" -> \"$LATEST\""
echo "  - VM distros defaultVersion (if present)"
echo ""

if [ "$AUTO_YES" -ne 1 ]; then
  read -r -p "Do you want to update? (y/n): " -n 1 REPLY
  echo ""
  if [[ ! ${REPLY:-} =~ ^[Yy]$ ]]; then
    echo "Update cancelled."
    exit 0
  fi
fi

cp "$FLAKE_FILE" "$FLAKE_FILE.bak"
echo "Backup: $FLAKE_FILE.bak"

# Inputs
sed -i \
  -e "s|nixos-${CURRENT}|nixos-${LATEST}|g" \
  -e "s|release-${CURRENT}|release-${LATEST}|g" \
  "$FLAKE_FILE"

# Prefer nixosRelease = "…"; fall back to legacy then/else "…" strings
if grep -qE 'nixosRelease[[:space:]]*=' "$FLAKE_FILE"; then
  sed -i -E "s/(nixosRelease[[:space:]]*=[[:space:]]*\")${CURRENT}(\")/\1${LATEST}\2/" "$FLAKE_FILE"
fi
sed -i -E "s/(then[[:space:]]*\")${CURRENT}(\")/\1${LATEST}\2/" "$FLAKE_FILE"
sed -i -E "s/(else[[:space:]]*\")${CURRENT}(\")/\1${LATEST}\2/" "$FLAKE_FILE"
# Bare stateVersion = "YY.MM" (without nixosRelease indirection)
sed -i -E "s/(stateVersion[[:space:]]*=[[:space:]]*\")${CURRENT}(\")/\1${LATEST}\2/" "$FLAKE_FILE"

if [ -f "$DISTROS_FILE" ]; then
  sed -i "s/defaultVersion = \"${CURRENT}\"/defaultVersion = \"${LATEST}\"/g" "$DISTROS_FILE"
  echo "Updated: $DISTROS_FILE"
fi

if [ -f "$USER_TEMPLATE" ]; then
  sed -i "s/stateVersion = \"${CURRENT}\"/stateVersion = \"${LATEST}\"/g" "$USER_TEMPLATE"
  echo "Updated: $USER_TEMPLATE"
fi

echo ""
echo "✓ Repo pin bumped to $LATEST"
echo ""
echo "Next steps:"
echo "  1. Review: git diff nixos/flake.nix nixos/modules/infrastructure/vm/lib/distros.nix"
echo "  2. Refresh lock:  cd nixos && nix flake update"
echo "  3. Tests:         bash shell/scripts/tests/run-all.sh"
echo "  4. Commit when green"
echo "  Restore backup:   cp $FLAKE_FILE.bak $FLAKE_FILE"
