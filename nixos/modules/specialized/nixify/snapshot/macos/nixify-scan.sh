#!/bin/bash
# Nixify macOS Snapshot Script
# Erfasst installierte Programme und System-Einstellungen für NixOS-Migration

set -euo pipefail

OUTPUT_FILE="${1:-nixify-report.json}"
UPLOAD="${2:-false}"
SERVER_URL="${3:-}"

echo "=== Nixify macOS Snapshot ==="
echo ""

# Initialize arrays
declare -a programs=()

# Hardware-Info
echo "📊 Collecting system information..."

CPU=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "unknown")
RAM=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
GPU=$(system_profiler SPDisplaysDataType 2>/dev/null | grep "Chipset Model" | head -1 | cut -d: -f2 | xargs || echo "unknown")

echo "  ✓ Hardware information collected"

# Installierte Programme
echo "📦 Collecting installed programs..."

# Applications
APP_COUNT=0
if [ -d "/Applications" ]; then
    while IFS= read -r app; do
        if [ -z "$app" ]; then continue; fi
        APP_NAME=$(basename "$app" .app)
        APP_VERSION=$(defaults read "$app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "unknown")
        programs+=("{\"name\":\"$APP_NAME\",\"version\":\"$APP_VERSION\",\"source\":\"applications\"}")
        ((APP_COUNT++))
    done < <(find /Applications -maxdepth 1 -name "*.app" -type d 2>/dev/null)
    echo "  ✓ Applications: $APP_COUNT"
fi

# Homebrew
if command -v brew &> /dev/null; then
    BREW_COUNT=0
    while IFS= read -r pkg; do
        if [ -z "$pkg" ]; then continue; fi
        # Escape quotes in package name
        PKG_ESCAPED=$(echo "$pkg" | sed 's/"/\\"/g')
        programs+=("{\"name\":\"$PKG_ESCAPED\",\"source\":\"homebrew\"}")
        ((BREW_COUNT++))
    done < <(brew list --formula 2>/dev/null)
    echo "  ✓ Homebrew packages: $BREW_COUNT"
fi

# Mac App Store (via mas)
if command -v mas &> /dev/null; then
    MAS_COUNT=0
    while IFS= read -r line; do
        if [ -z "$line" ]; then continue; fi
        APP_NAME=$(echo "$line" | awk -F'\t' '{print $2}')
        APP_ID=$(echo "$line" | awk -F'\t' '{print $1}')
        if [ -n "$APP_NAME" ]; then
            APP_ESCAPED=$(echo "$APP_NAME" | sed 's/"/\\"/g')
            programs+=("{\"name\":\"$APP_ESCAPED\",\"id\":\"$APP_ID\",\"source\":\"appstore\"}")
            ((MAS_COUNT++))
        fi
    done < <(mas list 2>/dev/null || true)
    if [ $MAS_COUNT -gt 0 ]; then
        echo "  ✓ Mac App Store apps: $MAS_COUNT"
    fi
fi

# System-Einstellungen
echo "⚙️  Collecting system settings..."

TIMEZONE=$(systemsetup -gettimezone 2>/dev/null | cut -d: -f2 | xargs || echo "unknown")
LOCALE=$(defaults read -g AppleLocale 2>/dev/null || echo "en_US")
DESKTOP="macos"

echo "  ✓ System settings collected"

# macOS Version
MACOS_VERSION=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
BUILD_VERSION=$(sw_vers -buildVersion 2>/dev/null || echo "unknown")

# JSON-Report generieren
echo ""
echo "📄 Generating report..."

# Create programs JSON array
# Security: IFS is set locally for this command only, not globally
PROGRAMS_JSON=""
if [ ${#programs[@]} -gt 0 ]; then
    PROGRAMS_JSON=$(IFS=,; echo "${programs[*]}")
fi

cat > "$OUTPUT_FILE" <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "os": "macos",
  "version": "$MACOS_VERSION",
  "build": "$BUILD_VERSION",
  "hardware": {
    "cpu": "$CPU",
    "ram": $RAM,
    "gpu": "$GPU"
  },
  "programs": [$PROGRAMS_JSON],
  "settings": {
    "timezone": "$TIMEZONE",
    "locale": "$LOCALE",
    "desktop": "$DESKTOP"
  }
}
EOF

echo "  ✓ Report saved to: $OUTPUT_FILE"
echo ""

# Summary
echo "=== Summary ==="
echo "  Programs found: ${#programs[@]}"
echo "  CPU: $CPU"
echo "  RAM: $((RAM / 1024 / 1024 / 1024)) GB"
echo "  GPU: $GPU"
echo ""

# Upload option
if [ "$UPLOAD" = "true" ] && [ -n "$SERVER_URL" ]; then
    echo "📤 Uploading report to server..."
    if curl -s -X POST "$SERVER_URL/api/v1/upload" \
        -H "Content-Type: application/json" \
        -d @"$OUTPUT_FILE" > /tmp/nixify-upload-response.json 2>&1; then
        SESSION_ID=$(cat /tmp/nixify-upload-response.json | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
        echo "  ✓ Upload successful! Session ID: $SESSION_ID"
    else
        echo "  ✗ Upload failed. Check server URL and network connection."
    fi
elif [ "$UPLOAD" = "true" ]; then
    echo "  ⚠ Upload requested but no server URL provided"
    echo "  Use: ./nixify-scan.sh report.json true http://your-nixos-server:8080"
fi

echo ""
echo "✅ Snapshot complete!"
echo "  Review the report and upload manually if needed:"
echo "  curl -X POST http://your-server:8080/api/v1/upload -H 'Content-Type: application/json' -d @$OUTPUT_FILE"
