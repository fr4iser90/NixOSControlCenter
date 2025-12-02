#!/usr/bin/env bash
# Test Package Structure ohne System zu ändern
# Prüft Syntax und Struktur, baut aber nichts

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🧪 Testing Package Structure (Dry-Run)..."
echo ""

# Test 1: Syntax-Check der Profile
echo "📋 Test 1: Profile Syntax-Check"
echo ""

for profile in fr4iser-home fr4iser-jetson gira-home; do
    profile_file="$PROJECT_ROOT/shell/scripts/setup/modes/profiles/$profile"
    if [[ -f "$profile_file" ]]; then
        echo -n "  Testing $profile... "
        if nix-instantiate --eval --strict -E "import $profile_file" > /dev/null 2>&1; then
            echo "✅ Syntax OK"
        else
            echo "❌ Syntax Error!"
            nix-instantiate --eval --strict -E "import $profile_file" 2>&1 | head -5
        fi
    fi
done

echo ""

# Test 2: Prüfe auf Namenskonflikt (features doppelt)
echo "📋 Test 2: Checking for name conflicts..."
echo ""

for profile in fr4iser-home fr4iser-jetson; do
    profile_file="$PROJECT_ROOT/shell/scripts/setup/modes/profiles/$profile"
    if [[ -f "$profile_file" ]]; then
        features_list_count=$(grep -c "features = \[" "$profile_file" || echo "0")
        features_set_count=$(grep -c "features = {" "$profile_file" || echo "0")
        
        if [[ $features_list_count -gt 0 && $features_set_count -gt 0 ]]; then
            echo "  ⚠️  $profile: CONFLICT! Both 'features = [' and 'features = {' found!"
            echo "     → Package Features werden von System Features überschrieben!"
        else
            echo "  ✅ $profile: No conflict"
        fi
    fi
done

echo ""

# Test 3: Test default.nix mit Test-Config
echo "📋 Test 3: Testing default.nix with test config..."
echo ""

# Erstelle temporäre Test-Config
test_config=$(mktemp)
cat > "$test_config" << 'EOF'
{
  systemType = "desktop";
  features = [ "streaming" "emulation" ];
}
EOF

echo "  Test config:"
cat "$test_config"
echo ""

# Test ob default.nix die Config verarbeiten kann
echo -n "  Testing default.nix import... "
if nix-instantiate --eval --strict -E "
  let
    systemConfig = import $test_config;
    pkgs = import <nixpkgs> {};
    lib = pkgs.lib;
  in
    import ${PROJECT_ROOT}/nixos/packages/default.nix {
      config = {};
      inherit lib pkgs systemConfig;
    }
" > /dev/null 2>&1; then
    echo "✅ OK"
else
    echo "❌ Error!"
    nix-instantiate --eval --strict -E "
      let
        systemConfig = import $test_config;
        pkgs = import <nixpkgs> {};
        lib = pkgs.lib;
      in
        import ${PROJECT_ROOT}/nixos/packages/default.nix {
          config = {};
          inherit lib pkgs systemConfig;
        }
    " 2>&1 | head -10
fi

rm -f "$test_config"

echo ""

# Test 4: Prüfe ob Features existieren
echo "📋 Test 4: Checking if all features exist..."
echo ""

required_features=(
    "streaming"
    "emulation"
    "game-dev"
    "web-dev"
    "python-dev"
    "system-dev"
    "docker"
    "docker-rootless"
    "database"
    "web-server"
    "mail-server"
    "qemu-vm"
    "virt-manager"
)

for feature in "${required_features[@]}"; do
    feature_file="$PROJECT_ROOT/nixos/packages/features/$feature.nix"
    if [[ -f "$feature_file" ]]; then
        echo "  ✅ $feature.nix exists"
    else
        echo "  ❌ $feature.nix MISSING!"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Test complete! (No system changes made)"
echo ""

