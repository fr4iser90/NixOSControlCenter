{ pkgs }:

pkgs.writeShellScriptBin "scan-packages" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail
  
  OUTPUT_FILE="$1"
  
  echo "📦 Scanning installed packages..."
  
  # Get NixOS packages
  NIX_PACKAGES="[]"
  if command -v nix-env >/dev/null 2>&1; then
    while IFS= read -r pkg; do
      if [ -n "$pkg" ]; then
        PKG_JSON=$(${pkgs.jq}/bin/jq -n --arg pkg "$pkg" '{name: $pkg, source: "nix-env"}')
        NIX_PACKAGES=$(${pkgs.jq}/bin/jq --argjson pkg "$PKG_JSON" '. + [$pkg]' <<< "$NIX_PACKAGES")
      fi
    done < <(nix-env -q --name-only 2>/dev/null || true)
  fi
  
  # Get system packages from /run/current-system
  SYSTEM_PACKAGES="[]"
  if [ -d /run/current-system ]; then
    while IFS= read -r pkg; do
      if [ -n "$pkg" ]; then
        PKG_JSON=$(${pkgs.jq}/bin/jq -n --arg pkg "$pkg" '{name: $pkg, source: "nixos-system"}')
        SYSTEM_PACKAGES=$(${pkgs.jq}/bin/jq --argjson pkg "$PKG_JSON" '. + [$pkg]' <<< "$SYSTEM_PACKAGES")
      fi
    done < <(ls /run/current-system/sw/bin 2>/dev/null | head -100 || true)
  fi
  
  # Get flatpak packages
  FLATPAK_PACKAGES="[]"
  if command -v flatpak >/dev/null 2>&1; then
    while IFS= read -r pkg; do
      if [ -n "$pkg" ]; then
        PKG_JSON=$(${pkgs.jq}/bin/jq -n --arg pkg "$pkg" '{name: $pkg, source: "flatpak"}')
        FLATPAK_PACKAGES=$(${pkgs.jq}/bin/jq --argjson pkg "$PKG_JSON" '. + [$pkg]' <<< "$FLATPAK_PACKAGES")
      fi
    done < <(flatpak list --columns=application 2>/dev/null | tail -n +2 || true)
  fi
  
  # Combine all packages
  ALL_PACKAGES=$(${pkgs.jq}/bin/jq -s 'add' <<< "$NIX_PACKAGES $SYSTEM_PACKAGES $FLATPAK_PACKAGES")
  
  # Output JSON
  ${pkgs.jq}/bin/jq -n \
    --argjson packages "$ALL_PACKAGES" \
    '{
      packages: {
        total: ($packages | length),
        bySource: {
          nixEnv: ($packages | map(select(.source == "nix-env")) | length),
          nixosSystem: ($packages | map(select(.source == "nixos-system")) | length),
          flatpak: ($packages | map(select(.source == "flatpak")) | length)
        },
        items: $packages
      }
    }' > "$OUTPUT_FILE"
  
  TOTAL=$(${pkgs.jq}/bin/jq '.packages.total' "$OUTPUT_FILE")
  echo "✅ Found $TOTAL packages"
''

