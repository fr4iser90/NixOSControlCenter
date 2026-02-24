#!/usr/bin/env bash
# Validierung und Build-Script für NixOS ISO
# Führt alle Validierungsschritte durch, baut die ISO und prüft den Output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_CONFIG="${SCRIPT_DIR}/iso-config.nix"
DESKTOP_ENV="${1:-plasma6}"

echo "=== NixOS ISO Validierung und Build ==="
echo "Desktop Environment: ${DESKTOP_ENV}"
echo ""

# Farben für Output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funktionen
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Schritt 1: Prüfe, ob iso-config.nix existiert
echo "Schritt 1: Prüfe ISO-Config..."
if [ ! -f "${ISO_CONFIG}" ]; then
    print_error "ISO-Config nicht gefunden: ${ISO_CONFIG}"
    exit 1
fi
print_success "ISO-Config gefunden"

# Schritt 2: Validiere, dass contents die richtige Anzahl Einträge hat
echo ""
echo "Schritt 2: Validiere contents-Liste..."
CONTENTS_COUNT=$(nix-instantiate --eval -E "with import <nixpkgs> {}; let eval = import <nixpkgs/nixos/lib/eval-config.nix> { system = \"x86_64-linux\"; specialArgs = { desktopEnv = \"${DESKTOP_ENV}\"; }; modules = [ ${ISO_CONFIG} ]; }; in builtins.length eval.config.isoImage.contents" 2>&1 | tail -1)
print_info "contents hat ${CONTENTS_COUNT} Einträge"

if [ "${CONTENTS_COUNT}" -lt 12 ]; then
    print_error "contents hat zu wenige Einträge (erwartet: >= 12, gefunden: ${CONTENTS_COUNT})"
    exit 1
fi
print_success "contents hat genügend Einträge"

# Schritt 3: Prüfe, ob die Derivationen in der ISO-Derivation referenziert sind
echo ""
echo "Schritt 3: Prüfe Derivation-Referenzen..."
ISO_DRV=$(nix-instantiate -E "with import <nixpkgs> {}; let eval = import <nixpkgs/nixos/lib/eval-config.nix> { system = \"x86_64-linux\"; specialArgs = { desktopEnv = \"${DESKTOP_ENV}\"; }; modules = [ ${ISO_CONFIG} ]; }; in eval.config.system.build.isoImage" 2>&1 | head -1)

if [ -z "${ISO_DRV}" ]; then
    print_error "ISO-Derivation konnte nicht erstellt werden"
    exit 1
fi
print_success "ISO-Derivation erstellt: ${ISO_DRV}"

# Prüfe, ob die Custom-Derivationen referenziert sind
REFERENCED=$(nix-store -q --tree "${ISO_DRV}" 2>&1 | grep -E "(calamares-settings-merged|calamares-modules|nixos-control-center-calamares-module)" | head -3 || true)

if [ -z "${REFERENCED}" ]; then
    print_error "Custom-Derivationen sind nicht im Dependency-Tree"
    print_info "Das könnte bedeuten, dass baseIsoModule die Liste überschreibt"
else
    print_success "Custom-Derivationen sind im Dependency-Tree referenziert"
    echo "${REFERENCED}"
fi

# Schritt 4: Prüfe, ob baseIsoModule lib.mkForce verwendet
echo ""
echo "Schritt 4: Prüfe baseIsoModule auf lib.mkForce..."
BASE_MODULE="<nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-graphical-calamares-${DESKTOP_ENV}.nix>"
MKFORCE_CHECK=$(grep -r "mkForce.*contents\|contents.*mkForce" "${BASE_MODULE}" 2>/dev/null || true)

if [ -n "${MKFORCE_CHECK}" ]; then
    print_error "baseIsoModule verwendet lib.mkForce für contents - Liste wird überschrieben!"
    exit 1
else
    print_success "baseIsoModule verwendet kein lib.mkForce für contents"
fi

# Schritt 5: Baue die ISO-Derivation (ohne vollständige ISO)
echo ""
echo "Schritt 5: Baue ISO-Derivation (Validierung)..."
print_info "Dies baut nur die Derivation, nicht die vollständige ISO"

BUILD_OUTPUT=$(nix-build -E "with import <nixpkgs> {}; let eval = import <nixpkgs/nixos/lib/eval-config.nix> { system = \"x86_64-linux\"; specialArgs = { desktopEnv = \"${DESKTOP_ENV}\"; }; modules = [ ${ISO_CONFIG} ]; }; in eval.config.system.build.isoImage" --no-out-link 2>&1 | tail -1)

if [ -z "${BUILD_OUTPUT}" ] || [ ! -d "${BUILD_OUTPUT}" ]; then
    print_error "ISO-Derivation konnte nicht gebaut werden"
    exit 1
fi
print_success "ISO-Derivation gebaut: ${BUILD_OUTPUT}"

# Schritt 6: Prüfe, ob die Dateien in der gebauten ISO-Struktur vorhanden sind
echo ""
echo "Schritt 6: Prüfe Dateien in ISO-Struktur..."
ISO_DIR="${BUILD_OUTPUT}/iso"

if [ ! -d "${ISO_DIR}" ]; then
    print_error "ISO-Verzeichnis nicht gefunden: ${ISO_DIR}"
    exit 1
fi

# Prüfe auf wichtige Dateien
MISSING_FILES=0

check_file() {
    local file="$1"
    local desc="$2"
    if [ -f "${ISO_DIR}/${file}" ] || [ -d "${ISO_DIR}/${file}" ]; then
        print_success "${desc} gefunden: ${file}"
    else
        print_error "${desc} fehlt: ${file}"
        MISSING_FILES=$((MISSING_FILES + 1))
    fi
}

check_file "etc/calamares/settings.conf" "Calamares settings.conf"
check_file "etc/calamares/modules.conf" "Calamares modules.conf"
check_file "usr/lib/calamares/modules/nixos-control-center" "Calamares GUI-Modul"
check_file "usr/lib/calamares/modules/nixos-control-center-job" "Calamares Job-Modul"
check_file "nixos/flake.nix" "NixOS Control Center Repository"

if [ "${MISSING_FILES}" -gt 0 ]; then
    print_error "${MISSING_FILES} Datei(en) fehlen in der ISO-Struktur"
    exit 1
fi

# Schritt 7: Baue vollständige ISO (wenn Validierung erfolgreich)
echo ""
echo "Schritt 7: Baue vollständige ISO..."
print_info "Dies kann einige Zeit dauern..."

# Prüfe, ob ncc verfügbar ist
if command -v ncc &> /dev/null; then
    print_info "Verwende ncc nixify build-iso..."
    if ncc nixify build-iso "${DESKTOP_ENV}" 2>&1; then
        print_success "ISO erfolgreich gebaut!"
        
        # Finde die gebaute ISO
        ISO_PATH=$(find ~/.local/share/nixify/isos -name "nixos-nixify-${DESKTOP_ENV}-*.iso" -type f | head -1)
        if [ -n "${ISO_PATH}" ]; then
            ISO_SIZE=$(du -h "${ISO_PATH}" | cut -f1)
            print_success "ISO gefunden: ${ISO_PATH}"
            print_info "ISO-Größe: ${ISO_SIZE}"
        fi
    else
        print_error "ISO-Build fehlgeschlagen"
        exit 1
    fi
else
    print_info "ncc nicht gefunden, verwende nix-build direkt..."
    FULL_ISO=$(nix-build -E "with import <nixpkgs> {}; let eval = import <nixpkgs/nixos/lib/eval-config.nix> { system = \"x86_64-linux\"; specialArgs = { desktopEnv = \"${DESKTOP_ENV}\"; }; modules = [ ${ISO_CONFIG} ]; }; in eval.config.system.build.isoImage" 2>&1 | tail -1)
    
    if [ -n "${FULL_ISO}" ] && [ -d "${FULL_ISO}" ]; then
        print_success "ISO erfolgreich gebaut: ${FULL_ISO}"
        ISO_FILE=$(find "${FULL_ISO}" -name "*.iso" -type f | head -1)
        if [ -n "${ISO_FILE}" ]; then
            ISO_SIZE=$(du -h "${ISO_FILE}" | cut -f1)
            print_success "ISO-Datei: ${ISO_FILE}"
            print_info "ISO-Größe: ${ISO_SIZE}"
        fi
    else
        print_error "ISO-Build fehlgeschlagen"
        exit 1
    fi
fi

# Schritt 8: Finale Validierung der gebauten ISO
echo ""
echo "Schritt 8: Finale Validierung der gebauten ISO..."

if [ -n "${ISO_PATH:-}" ] && [ -f "${ISO_PATH}" ]; then
    # Prüfe ISO-Datei
    if file "${ISO_PATH}" | grep -qE "ISO 9660|bootable"; then
        print_success "ISO-Datei ist gültig"
    else
        print_error "ISO-Datei scheint ungültig zu sein"
        exit 1
    fi
    
    # Versuche ISO zu mounten und Dateien zu prüfen (optional, benötigt sudo)
    if command -v 7z &> /dev/null; then
        print_info "Prüfe ISO-Inhalt mit 7z..."
        ISO_CONTENTS=$(7z l "${ISO_PATH}" 2>/dev/null | grep -E "(calamares|nixos-control-center)" | head -5 || true)
        if [ -n "${ISO_CONTENTS}" ]; then
            print_success "Custom-Dateien in ISO gefunden:"
            echo "${ISO_CONTENTS}"
        else
            print_error "Custom-Dateien nicht in ISO gefunden!"
            exit 1
        fi
    fi
fi

# Schritt 9: Zusammenfassung
echo ""
echo "=== Validierung und Build abgeschlossen ==="
print_success "Alle Schritte erfolgreich!"
if [ -n "${ISO_PATH:-}" ]; then
    print_info "ISO-Pfad: ${ISO_PATH}"
elif [ -n "${ISO_FILE:-}" ]; then
    print_info "ISO-Pfad: ${ISO_FILE}"
fi
print_info "ISO-Derivation: ${BUILD_OUTPUT}"
print_info "ISO-Verzeichnis: ${ISO_DIR}"
echo ""
