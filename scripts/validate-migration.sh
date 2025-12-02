#!/usr/bin/env bash
# Migration Validation Script
# Prüft ob die Package-Struktur-Migration korrekt durchgeführt wurde

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
ERRORS=0
WARNINGS=0
SUCCESS=0

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔍 Validating Package Structure Migration..."
echo ""

# Helper functions
error() {
    echo -e "${RED}❌ ERROR:${NC} $1"
    ((ERRORS++))
}

warning() {
    echo -e "${YELLOW}⚠️  WARNING:${NC} $1"
    ((WARNINGS++))
}

success() {
    echo -e "${GREEN}✅${NC} $1"
    ((SUCCESS++))
}

check_file_exists() {
    if [[ -f "$1" ]]; then
        success "File exists: $1"
        return 0
    else
        error "File missing: $1"
        return 1
    fi
}

check_dir_exists() {
    if [[ -d "$1" ]]; then
        success "Directory exists: $1"
        return 0
    else
        error "Directory missing: $1"
        return 1
    fi
}

check_file_not_exists() {
    if [[ ! -f "$1" ]]; then
        success "Old file correctly removed: $1"
        return 0
    else
        warning "Old file still exists (should be removed): $1"
        return 1
    fi
}

check_grep_not_found() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    
    if grep -q "$pattern" "$file" 2>/dev/null; then
        error "$description: Found '$pattern' in $file"
        return 1
    else
        success "$description: No '$pattern' in $file"
        return 0
    fi
}

check_grep_found() {
    local file="$1"
    local pattern="$2"
    local description="$3"
    
    if grep -q "$pattern" "$file" 2>/dev/null; then
        success "$description: Found '$pattern' in $file"
        return 0
    else
        error "$description: Missing '$pattern' in $file"
        return 1
    fi
}

# Phase 1-2: Structure & Metadata
echo "📁 Phase 1-2: Checking Structure & Metadata..."
echo ""

check_dir_exists "$PROJECT_ROOT/nixos/packages/features"
check_dir_exists "$PROJECT_ROOT/nixos/packages/presets"
check_file_exists "$PROJECT_ROOT/nixos/packages/metadata.nix"

# Check metadata.nix structure
if [[ -f "$PROJECT_ROOT/nixos/packages/metadata.nix" ]]; then
    if grep -q "features = {" "$PROJECT_ROOT/nixos/packages/metadata.nix"; then
        success "metadata.nix has 'features' definition"
    else
        error "metadata.nix missing 'features' definition"
    fi
fi

echo ""

# Phase 3: Feature Migration
echo "🔄 Phase 3: Checking Feature Migration..."
echo ""

# Gaming Features
check_file_exists "$PROJECT_ROOT/nixos/packages/features/streaming.nix"
check_file_exists "$PROJECT_ROOT/nixos/packages/features/emulation.nix"
check_file_not_exists "$PROJECT_ROOT/nixos/packages/modules/gaming/streaming.nix"
check_file_not_exists "$PROJECT_ROOT/nixos/packages/modules/gaming/emulation.nix"

# Development Features
check_file_exists "$PROJECT_ROOT/nixos/packages/features/game-dev.nix"
check_file_exists "$PROJECT_ROOT/nixos/packages/features/web-dev.nix"
check_file_exists "$PROJECT_ROOT/nixos/packages/features/python-dev.nix"
check_file_exists "$PROJECT_ROOT/nixos/packages/features/system-dev.nix"
check_file_exists "$PROJECT_ROOT/nixos/packages/features/qemu-vm.nix"
check_file_exists "$PROJECT_ROOT/nixos/packages/features/virt-manager.nix"
check_file_not_exists "$PROJECT_ROOT/nixos/packages/modules/development/game.nix"
check_file_not_exists "$PROJECT_ROOT/nixos/packages/modules/development/web.nix"

# Server Features
check_file_exists "$PROJECT_ROOT/nixos/packages/features/docker.nix"
check_file_exists "$PROJECT_ROOT/nixos/packages/features/docker-rootless.nix"
check_file_exists "$PROJECT_ROOT/nixos/packages/features/database.nix"
check_file_exists "$PROJECT_ROOT/nixos/packages/features/web-server.nix"
check_file_exists "$PROJECT_ROOT/nixos/packages/features/mail-server.nix"
check_file_not_exists "$PROJECT_ROOT/nixos/packages/modules/server/docker.nix"
check_file_not_exists "$PROJECT_ROOT/nixos/packages/modules/server/database.nix"

echo ""

# Phase 4: default.nix
echo "⚙️  Phase 4: Checking default.nix..."
echo ""

if [[ -f "$PROJECT_ROOT/nixos/packages/default.nix" ]]; then
    check_grep_found "$PROJECT_ROOT/nixos/packages/default.nix" "metadata.nix" "default.nix loads metadata"
    check_grep_found "$PROJECT_ROOT/nixos/packages/default.nix" "preset" "default.nix supports presets"
    check_grep_found "$PROJECT_ROOT/nixos/packages/default.nix" "features" "default.nix uses features"
    check_grep_not_found "$PROJECT_ROOT/nixos/packages/default.nix" "activeModules" "default.nix removed old activeModules"
    check_grep_not_found "$PROJECT_ROOT/nixos/packages/default.nix" "packageModules" "default.nix removed old packageModules logic"
else
    error "default.nix missing"
fi

echo ""

# Phase 5: Presets
echo "🎯 Phase 5: Checking Presets..."
echo ""

check_file_exists "$PROJECT_ROOT/nixos/packages/presets/gaming-desktop.nix"
check_file_exists "$PROJECT_ROOT/nixos/packages/presets/dev-workstation.nix"
check_file_exists "$PROJECT_ROOT/nixos/packages/presets/homelab-server.nix"

# Check preset structure
for preset in gaming-desktop dev-workstation homelab-server; do
    if [[ -f "$PROJECT_ROOT/nixos/packages/presets/$preset.nix" ]]; then
        if grep -q "features = \[" "$PROJECT_ROOT/nixos/packages/presets/$preset.nix"; then
            success "Preset $preset has 'features' list"
        else
            error "Preset $preset missing 'features' list"
        fi
    fi
done

echo ""

# Phase 6-7: Scripts
echo "📜 Phase 6-7: Checking Scripts..."
echo ""

# Desktop Setup
if [[ -f "$PROJECT_ROOT/shell/scripts/setup/modes/desktop/setup.sh" ]]; then
    check_grep_not_found "$PROJECT_ROOT/shell/scripts/setup/modes/desktop/setup.sh" \
        '/gaming = {/,/};/s/streaming' \
        "Desktop setup removed old gaming sed commands"
    check_grep_not_found "$PROJECT_ROOT/shell/scripts/setup/modes/desktop/setup.sh" \
        '/development = {/,/};/s/web' \
        "Desktop setup removed old development sed commands"
    check_grep_found "$PROJECT_ROOT/shell/scripts/setup/modes/desktop/setup.sh" \
        "features" \
        "Desktop setup uses features"
fi

# Server Setup
if [[ -f "$PROJECT_ROOT/shell/scripts/setup/modes/server/setup.sh" ]]; then
    check_grep_not_found "$PROJECT_ROOT/shell/scripts/setup/modes/server/setup.sh" \
        '/server = {/,/};/s/docker' \
        "Server setup removed old server sed commands"
    check_grep_found "$PROJECT_ROOT/shell/scripts/setup/modes/server/setup.sh" \
        "features" \
        "Server setup uses features"
fi

# UI/Prompts
if [[ -f "$PROJECT_ROOT/shell/scripts/ui/prompts/setup-options.sh" ]]; then
    check_grep_not_found "$PROJECT_ROOT/shell/scripts/ui/prompts/setup-options.sh" \
        "Gaming-Streaming" \
        "setup-options.sh removed old Gaming-Streaming"
    check_grep_found "$PROJECT_ROOT/shell/scripts/ui/prompts/setup-options.sh" \
        "streaming\|emulation" \
        "setup-options.sh uses new feature names"
fi

if [[ -f "$PROJECT_ROOT/shell/scripts/ui/prompts/setup-rules.sh" ]]; then
    check_grep_not_found "$PROJECT_ROOT/shell/scripts/ui/prompts/setup-rules.sh" \
        '\["Gaming-Streaming"\]' \
        "setup-rules.sh removed old Gaming-Streaming"
fi

echo ""

# Phase 8: Config Template
echo "📋 Phase 8: Checking Config Template..."
echo ""

if [[ -f "$PROJECT_ROOT/shell/scripts/setup/config/system-config.template.nix" ]]; then
    check_grep_not_found "$PROJECT_ROOT/shell/scripts/setup/config/system-config.template.nix" \
        "packageModules = {" \
        "Template removed old packageModules structure"
    check_grep_found "$PROJECT_ROOT/shell/scripts/setup/config/system-config.template.nix" \
        "features = \[" \
        "Template uses new features structure"
fi

if [[ -f "$PROJECT_ROOT/shell/scripts/setup/config/data-collection/collect-system-data.sh" ]]; then
    check_grep_not_found "$PROJECT_ROOT/shell/scripts/setup/config/data-collection/collect-system-data.sh" \
        "@GAMING_STREAMING@" \
        "collect-system-data.sh removed old placeholders"
    check_grep_found "$PROJECT_ROOT/shell/scripts/setup/config/data-collection/collect-system-data.sh" \
        "@PACKAGE_MODULES@\|@PRESET@\|@ADDITIONAL_PACKAGE_MODULES@" \
        "collect-system-data.sh uses new placeholders"
fi

echo ""

# Phase 9: Profile Migration
echo "👤 Phase 9: Checking Profile Migration..."
echo ""

for profile in fr4iser-home fr4iser-jetson gira-home; do
    profile_file="$PROJECT_ROOT/shell/scripts/setup/modes/profiles/$profile"
    if [[ -f "$profile_file" ]]; then
        if grep -q "packageModules = {" "$profile_file"; then
            warning "Profile $profile still uses old packageModules structure"
        else
            success "Profile $profile migrated (no packageModules)"
        fi
        
        if grep -q "features = \[" "$profile_file" || grep -q "preset = " "$profile_file"; then
            success "Profile $profile uses new features/preset structure"
        else
            warning "Profile $profile might not be fully migrated"
        fi
    fi
done

echo ""

# Phase 10-11: Documentation & Cleanup
echo "📚 Phase 10-11: Checking Documentation & Cleanup..."
echo ""

# Check if old modules directory still exists
if [[ -d "$PROJECT_ROOT/nixos/packages/modules" ]]; then
    if [[ -n "$(find "$PROJECT_ROOT/nixos/packages/modules" -type f 2>/dev/null)" ]]; then
        warning "Old modules/ directory still contains files"
    else
        success "Old modules/ directory is empty (ready for deletion)"
    fi
else
    success "Old modules/ directory removed"
fi

# Check README
if [[ -f "$PROJECT_ROOT/README.md" ]]; then
    if grep -q "modules/" "$PROJECT_ROOT/README.md" && ! grep -q "features/" "$PROJECT_ROOT/README.md"; then
        warning "README.md still mentions modules/ but not features/"
    elif grep -q "features/" "$PROJECT_ROOT/README.md"; then
        success "README.md updated to mention features/"
    fi
fi

echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Validation Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Success:${NC} $SUCCESS"
echo -e "${YELLOW}⚠️  Warnings:${NC} $WARNINGS"
echo -e "${RED}❌ Errors:${NC} $ERRORS"
echo ""

if [[ $ERRORS -eq 0 ]]; then
    if [[ $WARNINGS -eq 0 ]]; then
        echo -e "${GREEN}🎉 Migration validation PASSED! All checks successful.${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠️  Migration validation PASSED with warnings. Please review warnings above.${NC}"
        exit 0
    fi
else
    echo -e "${RED}❌ Migration validation FAILED! Please fix errors above.${NC}"
    exit 1
fi

