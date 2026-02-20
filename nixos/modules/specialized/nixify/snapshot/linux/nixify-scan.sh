#!/bin/bash
# Nixify Linux Snapshot Script
# Erfasst installierte Programme und System-Einstellungen für NixOS-Migration

set -euo pipefail

OUTPUT_FILE="${1:-nixify-report.json}"
UPLOAD="${2:-false}"
SERVER_URL="${3:-}"

echo "=== Nixify Linux Snapshot ==="
echo ""

# Initialize arrays
declare -a programs=()

# Distro-Erkennung
echo "📊 Detecting distribution..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="$ID"
    DISTRO_VERSION="${VERSION_ID:-unknown}"
    DISTRO_NAME="${NAME:-unknown}"
else
    DISTRO_ID="unknown"
    DISTRO_VERSION="unknown"
    DISTRO_NAME="unknown"
fi

echo "  ✓ Distribution: $DISTRO_NAME ($DISTRO_ID $DISTRO_VERSION)"

# Hardware-Info
echo "📊 Collecting hardware information..."

CPU="unknown"
RAM=0
GPU="unknown"

# CPU
if command -v lscpu &> /dev/null; then
    CPU=$(lscpu | grep "Model name" | cut -d: -f2 | xargs || echo "unknown")
elif [ -f /proc/cpuinfo ]; then
    CPU=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs || echo "unknown")
fi

# RAM
if command -v free &> /dev/null; then
    RAM=$(free -b | grep "Mem:" | awk '{print $2}' || echo "0")
elif [ -f /proc/meminfo ]; then
    RAM=$(grep "MemTotal" /proc/meminfo | awk '{print $2 * 1024}' || echo "0")
fi

# GPU
if command -v lspci &> /dev/null; then
    GPU=$(lspci | grep -i "vga\|3d\|display" | head -1 | cut -d: -f3 | xargs || echo "unknown")
fi

echo "  ✓ Hardware information collected"

# Package Manager Detection
echo "📦 Detecting package manager..."

PACKAGE_MANAGER="unknown"
PACKAGE_COUNT=0

if command -v apt &> /dev/null || command -v apt-get &> /dev/null; then
    PACKAGE_MANAGER="apt"
    while IFS= read -r pkg; do
        if [ -z "$pkg" ]; then continue; fi
        PKG_ESCAPED=$(echo "$pkg" | sed 's/"/\\"/g')
        programs+=("{\"name\":\"$PKG_ESCAPED\",\"source\":\"apt\"}")
        ((PACKAGE_COUNT++))
    done < <(dpkg-query -W -f='${Package}\n' 2>/dev/null | head -100)
    echo "  ✓ APT packages: $PACKAGE_COUNT"
elif command -v dnf &> /dev/null; then
    PACKAGE_MANAGER="dnf"
    while IFS= read -r pkg; do
        if [ -z "$pkg" ]; then continue; fi
        PKG_NAME=$(echo "$pkg" | cut -d'-' -f1)
        PKG_ESCAPED=$(echo "$PKG_NAME" | sed 's/"/\\"/g')
        programs+=("{\"name\":\"$PKG_ESCAPED\",\"source\":\"dnf\"}")
        ((PACKAGE_COUNT++))
    done < <(rpm -qa 2>/dev/null | head -100)
    echo "  ✓ DNF packages: $PACKAGE_COUNT"
elif command -v pacman &> /dev/null; then
    PACKAGE_MANAGER="pacman"
    while IFS= read -r line; do
        if [ -z "$line" ]; then continue; fi
        PKG_NAME=$(echo "$line" | cut -d' ' -f1)
        PKG_ESCAPED=$(echo "$PKG_NAME" | sed 's/"/\\"/g')
        programs+=("{\"name\":\"$PKG_ESCAPED\",\"source\":\"pacman\"}")
        ((PACKAGE_COUNT++))
    done < <(pacman -Q 2>/dev/null | head -100)
    echo "  ✓ Pacman packages: $PACKAGE_COUNT"
elif command -v zypper &> /dev/null; then
    PACKAGE_MANAGER="zypper"
    while IFS= read -r pkg; do
        if [ -z "$pkg" ]; then continue; fi
        PKG_NAME=$(echo "$pkg" | cut -d'-' -f1)
        PKG_ESCAPED=$(echo "$PKG_NAME" | sed 's/"/\\"/g')
        programs+=("{\"name\":\"$PKG_ESCAPED\",\"source\":\"zypper\"}")
        ((PACKAGE_COUNT++))
    done < <(rpm -qa 2>/dev/null | head -100)
    echo "  ✓ Zypper packages: $PACKAGE_COUNT"
elif command -v nix &> /dev/null; then
    PACKAGE_MANAGER="nix"
    echo "  ℹ NixOS detected - this script is for migrating TO NixOS"
    echo "  Use nixos-rebuild or nix-collect-garbage for NixOS systems"
fi

# Flatpak
if command -v flatpak &> /dev/null; then
    FLATPAK_COUNT=0
    while IFS= read -r app; do
        if [ -z "$app" ]; then continue; fi
        APP_ESCAPED=$(echo "$app" | sed 's/"/\\"/g')
        programs+=("{\"name\":\"$APP_ESCAPED\",\"source\":\"flatpak\"}")
        ((FLATPAK_COUNT++))
    done < <(flatpak list --app --columns=application 2>/dev/null | tail -n +2)
    if [ $FLATPAK_COUNT -gt 0 ]; then
        echo "  ✓ Flatpak apps: $FLATPAK_COUNT"
    fi
fi

# Snap
if command -v snap &> /dev/null; then
    SNAP_COUNT=0
    while IFS= read -r app; do
        if [ -z "$app" ] || [ "$app" = "Name" ]; then continue; fi
        APP_NAME=$(echo "$app" | awk '{print $1}')
        APP_ESCAPED=$(echo "$APP_NAME" | sed 's/"/\\"/g')
        programs+=("{\"name\":\"$APP_ESCAPED\",\"source\":\"snap\"}")
        ((SNAP_COUNT++))
    done < <(snap list 2>/dev/null | tail -n +2)
    if [ $SNAP_COUNT -gt 0 ]; then
        echo "  ✓ Snap packages: $SNAP_COUNT"
    fi
fi

# Desktop Environment
echo "⚙️  Detecting desktop environment..."

DESKTOP_ENV="${XDG_CURRENT_DESKTOP:-unknown}"
if [ "$DESKTOP_ENV" = "unknown" ] || [ -z "$DESKTOP_ENV" ]; then
    if [ -n "${XDG_DATA_DIRS:-}" ]; then
        if echo "$XDG_DATA_DIRS" | grep -q "gnome"; then
            DESKTOP_ENV="GNOME"
        elif echo "$XDG_DATA_DIRS" | grep -q "kde"; then
            DESKTOP_ENV="KDE"
        elif echo "$XDG_DATA_DIRS" | grep -q "xfce"; then
            DESKTOP_ENV="XFCE"
        fi
    fi
fi

# Service Manager
SERVICE_MANAGER="unknown"
if systemctl --version &> /dev/null; then
    SERVICE_MANAGER="systemd"
elif [ -d /etc/init.d ]; then
    SERVICE_MANAGER="sysvinit"
elif command -v openrc &> /dev/null; then
    SERVICE_MANAGER="openrc"
fi

# System-Einstellungen
TIMEZONE="unknown"
LOCALE="unknown"

if command -v timedatectl &> /dev/null; then
    TIMEZONE=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "unknown")
elif [ -f /etc/timezone ]; then
    TIMEZONE=$(cat /etc/timezone | xargs || echo "unknown")
fi

if [ -n "${LANG:-}" ]; then
    LOCALE=$(echo "$LANG" | cut -d. -f1 || echo "unknown")
elif [ -f /etc/default/locale ]; then
    LOCALE=$(grep "^LANG=" /etc/default/locale | cut -d= -f2 | cut -d. -f1 || echo "unknown")
fi

echo "  ✓ System settings collected"

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
  "os": "linux",
  "distro": {
    "id": "$DISTRO_ID",
    "version": "$DISTRO_VERSION",
    "name": "$DISTRO_NAME"
  },
  "hardware": {
    "cpu": "$CPU",
    "ram": $RAM,
    "gpu": "$GPU"
  },
  "package_manager": "$PACKAGE_MANAGER",
  "service_manager": "$SERVICE_MANAGER",
  "programs": [$PROGRAMS_JSON],
  "settings": {
    "timezone": "$TIMEZONE",
    "locale": "$LOCALE",
    "desktop": "$DESKTOP_ENV"
  }
}
EOF

echo "  ✓ Report saved to: $OUTPUT_FILE"
echo ""

# Summary
echo "=== Summary ==="
echo "  Distribution: $DISTRO_NAME ($DISTRO_ID $DISTRO_VERSION)"
echo "  Package Manager: $PACKAGE_MANAGER"
echo "  Programs found: ${#programs[@]}"
echo "  CPU: $CPU"
echo "  RAM: $((RAM / 1024 / 1024 / 1024)) GB"
echo "  GPU: $GPU"
echo "  Desktop: $DESKTOP_ENV"
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
