#!/usr/bin/env bash
# Script to rename all step-recorder references to chronicle
# Run from the chronicle directory

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🔄 Renaming step-recorder to chronicle..."
echo "📂 Working directory: $SCRIPT_DIR"
echo ""

# Backup
BACKUP_DIR="$SCRIPT_DIR/.backup-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
echo "💾 Creating backup in: $BACKUP_DIR"

# Find all relevant files (excluding this script and backup)
find . -type f \( \
    -name "*.nix" -o \
    -name "*.sh" -o \
    -name "*.md" -o \
    -name "*.py" -o \
    -name "*.json" -o \
    -name "*.txt" \
\) ! -path "./.backup-*/*" ! -name "rename-to-chronicle.sh" -print0 | while IFS= read -r -d '' file; do
    # Skip if file doesn't contain step-recorder
    if ! grep -q "step-recorder\|stepRecorder\|STEP_RECORDER" "$file" 2>/dev/null; then
        continue
    fi
    
    # Backup original file
    backup_file="$BACKUP_DIR${file#.}"
    mkdir -p "$(dirname "$backup_file")"
    cp "$file" "$backup_file"
    
    echo "  📝 Processing: $file"
    
    # Perform replacements
    # 1. Environment variables: STEP_RECORDER → CHRONICLE
    sed -i 's/STEP_RECORDER/CHRONICLE/g' "$file"
    
    # 2. Command names: step-recorder → chronicle
    sed -i 's/step-recorder/chronicle/g' "$file"
    
    # 3. CamelCase variables: stepRecorder → chronicle (careful with this)
    sed -i 's/stepRecorderLib/chronicleLib/g' "$file"
    sed -i 's/stepRecorder/chronicle/g' "$file"
    
    # 4. Service names in systemd
    sed -i 's/"step-recorder"/"chronicle"/g' "$file"
    
    # 5. Directory names in paths
    sed -i 's|/step-recorder|/chronicle|g' "$file"
    sed -i 's|nixos-step-recorder|nixos-chronicle|g' "$file"
    
    # 6. Specific file references
    sed -i 's/step-recorder\.lock/chronicle.lock/g' "$file"
    sed -i 's/step-recorder\.state/chronicle.state/g' "$file"
    sed -i 's/step-recorder\.log/chronicle.log/g' "$file"
    sed -i 's/step-recorder\.pid/chronicle.pid/g' "$file"
    
    # 7. Update module paths (but keep Step Recorder in human-readable descriptions)
    # This is tricky - we want to keep "Step Recorder" in descriptions but change technical refs
done

echo ""
echo "✅ Renaming complete!"
echo ""
echo "📊 Summary:"
echo "   Backup created: $BACKUP_DIR"
echo "   Files processed: $(find . -type f \( -name "*.nix" -o -name "*.sh" -o -name "*.md" \) ! -path "./.backup-*/*" ! -name "rename-to-chronicle.sh" | wc -l)"
echo ""
echo "🔍 Verification:"
echo "   Remaining 'step-recorder' references: $(grep -r "step-recorder" --include="*.nix" --include="*.sh" --exclude-dir=".backup-*" --exclude="rename-to-chronicle.sh" . 2>/dev/null | wc -l)"
echo ""
echo "ℹ️  Note: Some references in documentation may intentionally remain"
echo "   (e.g., 'formerly known as Step Recorder', historical references)"
echo ""
echo "🗑️  To remove backup: rm -rf $BACKUP_DIR"
