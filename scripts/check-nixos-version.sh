#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FLAKE_FILE="$REPO_ROOT/nixos/flake.nix"

echo "=== NixOS Version Check ==="
echo ""

# Get current version from flake.nix
if [ ! -f "$FLAKE_FILE" ]; then
    echo "Error: $FLAKE_FILE not found!"
    exit 1
fi

CURRENT=$(grep 'nixos-' "$FLAKE_FILE" | grep -oE 'nixos-[0-9]+\.[0-9]+' | head -1 | sed 's/nixos-//')

if [ -z "$CURRENT" ]; then
    echo "Error: Could not find current version in flake.nix"
    exit 1
fi

echo "Current version: $CURRENT"

echo "Fetching latest version..."

LATEST=""

if [ -z "$LATEST" ]; then
    GITHUB_PAGE=$(curl -s "https://github.com/NixOS/nixpkgs/branches" 2>/dev/null)
    if [ -n "$GITHUB_PAGE" ]; then
        LATEST=$(echo "$GITHUB_PAGE" | grep -oE 'nixos-[0-9]+\.[0-9]+' | sed 's/nixos-//' | sort -V | tail -1)
    fi
fi

if [ -z "$LATEST" ]; then
    API_RESPONSE=$(curl -s "https://api.github.com/repos/NixOS/nixpkgs/branches?per_page=100" 2>/dev/null)
    if [ -n "$API_RESPONSE" ]; then
        LATEST=$(echo "$API_RESPONSE" | grep -oE '"name"\s*:\s*"nixos-[0-9]+\.[0-9]+"' | grep -oE '[0-9]+\.[0-9]+' | sort -V | tail -1)
    fi
fi

if [ -z "$LATEST" ]; then
    echo "Error: Could not determine latest version"
    exit 1
fi

echo "Latest version: $LATEST"
echo ""

# Compare versions
if [ "$CURRENT" = "$LATEST" ]; then
    echo "✓ You are already on the latest version: $CURRENT"
    exit 0
fi

echo "Update available: $CURRENT -> $LATEST"
echo ""
echo "This will update:"
echo "  - nixpkgs-stable: nixos-$CURRENT -> nixos-$LATEST"
echo "  - home-manager-stable: release-$CURRENT -> release-$LATEST"
echo "  - stateVersion: \"$CURRENT\" -> \"$LATEST\""
echo "  - system-config.template.nix: version \"$CURRENT\" -> \"$LATEST\""
echo "  - vm-manager/lib/distros.nix: defaultVersion \"$CURRENT\" -> \"$LATEST\""
echo ""

# Ask for confirmation
read -p "Do you want to update? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Update cancelled."
    exit 0
fi

echo ""
echo "Updating flake.nix..."

# Backup
cp "$FLAKE_FILE" "$FLAKE_FILE.bak"
echo "Backup created: $FLAKE_FILE.bak"

# Update flake.nix
sed -i "s/nixos-${CURRENT}/nixos-${LATEST}/g" "$FLAKE_FILE"
sed -i "s/release-${CURRENT}/release-${LATEST}/g" "$FLAKE_FILE"
sed -i "s/then \"${CURRENT}\"/then \"${LATEST}\"/g" "$FLAKE_FILE"

UNSTABLE_CURRENT=$(grep 'else "' "$FLAKE_FILE" | grep -oE '[0-9]+\.[0-9]+' | head -1 || echo "")
if [ -n "$UNSTABLE_CURRENT" ] && [ "$UNSTABLE_CURRENT" != "$LATEST" ]; then
    echo "Also updating unstable version: $UNSTABLE_CURRENT -> $LATEST"
    sed -i "s/else \"${UNSTABLE_CURRENT}\"/else \"${LATEST}\"/g" "$FLAKE_FILE"
fi

# Update other files with version references
TEMPLATE_FILE="$REPO_ROOT/shell/scripts/setup/config/system-config.template.nix"
if [ -f "$TEMPLATE_FILE" ]; then
    sed -i "s/version = \"${CURRENT}\"/version = \"${LATEST}\"/g" "$TEMPLATE_FILE"
    echo "Updated: system-config.template.nix"
fi

DISTROS_FILE="$REPO_ROOT/nixos/features/vm-manager/lib/distros.nix"
if [ -f "$DISTROS_FILE" ]; then
    sed -i "s/defaultVersion = \"${CURRENT}\"/defaultVersion = \"${LATEST}\"/g" "$DISTROS_FILE"
    echo "Updated: vm-manager/lib/distros.nix"
fi

echo ""
echo "✓ Updated successfully!"
echo ""
echo "Changes:"
git --no-pager diff "$FLAKE_FILE" "$TEMPLATE_FILE" "$DISTROS_FILE" 2>/dev/null || git --no-pager diff "$FLAKE_FILE" || true
echo ""
echo "Next steps:"
echo "  1. Review the changes above"
echo "  2. If everything looks good, commit: git add nixos/flake.nix shell/scripts/setup/config/system-config.template.nix nixos/features/vm-manager/lib/distros.nix && git commit -m 'chore: update NixOS version to $LATEST'"
echo "  3. If something is wrong, restore: cp $FLAKE_FILE.bak $FLAKE_FILE"

