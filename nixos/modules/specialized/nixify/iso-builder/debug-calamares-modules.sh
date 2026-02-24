#!/usr/bin/env bash
# debug-calamares-modules.sh
# Debug-Script zum Vergleichen unserer Module mit Standard-Modulen

set -e

# Standard-Pfad: ~/.local/share/nixify/isos/*.iso
# Falls kein Parameter, suche dort
if [ -z "$1" ]; then
    ISO_PATH=$(find ~/.local/share/nixify/isos -name "nixos-nixify-*.iso" -type f 2>/dev/null | head -1)
    if [ -z "$ISO_PATH" ]; then
        echo "❌ Keine ISO gefunden unter ~/.local/share/nixify/isos/"
        echo "Usage: $0 [path/to/iso]"
        exit 1
    fi
    echo "Gefundene ISO: $ISO_PATH"
else
    ISO_PATH="$1"
    if [ ! -f "$ISO_PATH" ]; then
        echo "❌ ISO-Datei nicht gefunden: $ISO_PATH"
        exit 1
    fi
fi

MOUNT_POINT="/mnt/iso-debug"

echo "=== Calamares Module Debug ==="
echo "ISO: $ISO_PATH"
echo ""

# ISO mounten
echo "1. Mounte ISO..."
mkdir -p "$MOUNT_POINT" 2>/dev/null || true
if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
    echo "ISO bereits gemountet unter $MOUNT_POINT"
else
    echo "Mounte: $ISO_PATH"
    sudo mount -o loop "$ISO_PATH" "$MOUNT_POINT" || {
        echo "❌ Fehler beim Mounten der ISO"
        echo "Versuche ohne sudo..."
        # Versuche ohne sudo (falls bereits gemountet)
        if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
            echo "ISO ist bereits gemountet"
        else
            echo "❌ Benötige sudo zum Mounten"
            exit 1
        fi
    }
fi

# Squashfs mounten - in separates Verzeichnis, da ISO read-only ist
SQUASHFS="$MOUNT_POINT/nix-store.squashfs"
SQUASHFS_MOUNT="$MOUNT_POINT-squashfs"  # Separates Verzeichnis für squashfs
if [ -f "$SQUASHFS" ]; then
    echo "2. Mounte squashfs..."
    sudo mkdir -p "$SQUASHFS_MOUNT"
    if mountpoint -q "$SQUASHFS_MOUNT" 2>/dev/null; then
        echo "Squashfs bereits gemountet unter $SQUASHFS_MOUNT"
    else
        sudo mount -t squashfs "$SQUASHFS" "$SQUASHFS_MOUNT" || {
            echo "❌ Fehler beim Mounten des squashfs"
            exit 1
        }
    fi
else
    echo "⚠️  Kein squashfs gefunden unter $SQUASHFS"
fi

echo ""
echo "=== Standard Calamares Module ==="
echo ""

# Finde Standard-Module
echo "3. Suche Standard-Module..."
STANDARD_MODULES=$(find "$SQUASHFS_MOUNT" -path "*/calamares*/modules/*" -name "module.desc" 2>/dev/null | head -5)
if [ -z "$STANDARD_MODULES" ]; then
    echo "⚠️  Keine Standard-Module gefunden"
else
    echo "$STANDARD_MODULES" | while read -r desc; do
        module_dir=$(dirname "$desc")
        module_name=$(basename "$module_dir")
        echo ""
        echo "--- Standard Module: $module_name ---"
        echo "Pfad: $module_dir"
        echo ""
        echo "Inhalt:"
        ls -la "$module_dir" 2>/dev/null | head -10 || echo "Fehler beim Auflisten"
        echo ""
        echo "module.desc:"
        cat "$desc" 2>/dev/null || echo "Fehler beim Lesen"
        echo ""
        echo "---"
    done
fi

echo ""
echo "=== Unsere Module auf der ISO ==="
echo ""

# Finde unsere Module
echo "4. Suche unsere Module..."
echo ""
echo "4a. Prüfe ISO-Dateisystem..."
if [ -d "$MOUNT_POINT/usr/lib/calamares/modules" ]; then
    for module in nixos-control-center nixos-control-center-job; do
        module_path="$MOUNT_POINT/usr/lib/calamares/modules/$module"
        echo ""
        echo "--- Unser Module: $module ---"
        if [ -e "$module_path" ]; then
            echo "Pfad: $module_path"
            echo "Typ: $(file "$module_path" 2>/dev/null || echo "unbekannt")"
            if [ -L "$module_path" ]; then
                link_target=$(readlink "$module_path")
                echo "→ Symlink zu: $link_target"
                real_path=$(readlink -f "$module_path" 2>/dev/null || echo "nicht auflösbar")
                echo "→ Real path: $real_path"
                if [ ! -e "$real_path" ]; then
                    echo "❌ Symlink-Ziel existiert nicht!"
                fi
            fi
            echo ""
            echo "Inhalt:"
            if [ -d "$module_path" ]; then
                ls -la "$module_path"
            elif [ -L "$module_path" ]; then
                target=$(readlink "$module_path")
                if [ -d "$target" ]; then
                    echo "Symlink-Ziel (direkt):"
                    ls -la "$target"
                    echo ""
                    echo "Symlink-Ziel (realpath):"
                    real_target=$(readlink -f "$module_path")
                    if [ -d "$real_target" ]; then
                        ls -la "$real_target"
                    else
                        echo "❌ Realpath existiert nicht: $real_target"
                    fi
                else
                    echo "❌ Symlink-Ziel ist kein Verzeichnis: $target"
                fi
            fi
            echo ""
            if [ -f "$module_path/module.desc" ]; then
                echo "module.desc (direkt):"
                cat "$module_path/module.desc"
            elif [ -L "$module_path" ]; then
                real_module_path=$(readlink -f "$module_path")
                if [ -f "$real_module_path/module.desc" ]; then
                    echo "module.desc (via Symlink):"
                    cat "$real_module_path/module.desc"
                else
                    echo "❌ module.desc nicht gefunden unter $real_module_path/module.desc"
                fi
            else
                echo "❌ module.desc nicht gefunden!"
            fi
        else
            echo "❌ $module nicht gefunden unter $module_path"
        fi
        echo ""
    done
else
    echo "❌ /usr/lib/calamares/modules nicht gefunden auf ISO-Dateisystem"
    echo "Verfügbare Verzeichnisse unter $MOUNT_POINT/usr/lib:"
    ls -la "$MOUNT_POINT/usr/lib" 2>/dev/null | head -10 || echo "Fehler"
fi

echo ""
echo "4b. Prüfe squashfs (Live-System)..."
if [ -d "$SQUASHFS_MOUNT/usr/lib/calamares/modules" ]; then
    echo "✓ /usr/lib/calamares/modules gefunden im squashfs!"
    for module in nixos-control-center nixos-control-center-job; do
        module_path="$SQUASHFS_MOUNT/usr/lib/calamares/modules/$module"
        echo ""
        echo "--- Unser Module im squashfs: $module ---"
        if [ -e "$module_path" ]; then
            echo "Pfad: $module_path"
            echo "Typ: $(file "$module_path" 2>/dev/null || echo "unbekannt")"
            if [ -L "$module_path" ]; then
                link_target=$(readlink "$module_path")
                echo "→ Symlink zu: $link_target"
                real_path=$(readlink -f "$module_path" 2>/dev/null || echo "nicht auflösbar")
                echo "→ Real path: $real_path"
                if [ ! -e "$real_path" ]; then
                    echo "❌ Symlink-Ziel existiert nicht!"
                else
                    echo "✓ Symlink-Ziel existiert"
                fi
            fi
            echo ""
            echo "Inhalt:"
            if [ -d "$module_path" ]; then
                ls -la "$module_path"
            elif [ -L "$module_path" ]; then
                real_target=$(readlink -f "$module_path")
                if [ -d "$real_target" ]; then
                    echo "Symlink-Ziel (realpath):"
                    ls -la "$real_target"
                else
                    echo "❌ Realpath existiert nicht: $real_target"
                fi
            fi
            echo ""
            if [ -f "$module_path/module.desc" ]; then
                echo "module.desc (direkt):"
                cat "$module_path/module.desc"
            elif [ -L "$module_path" ]; then
                real_module_path=$(readlink -f "$module_path")
                if [ -f "$real_module_path/module.desc" ]; then
                    echo "module.desc (via Symlink):"
                    cat "$real_module_path/module.desc"
                else
                    echo "❌ module.desc nicht gefunden unter $real_module_path/module.desc"
                fi
            else
                echo "❌ module.desc nicht gefunden!"
            fi
        else
            echo "❌ $module nicht gefunden unter $module_path"
        fi
        echo ""
    done
else
    echo "❌ /usr/lib/calamares/modules nicht gefunden im squashfs"
    echo "Suche nach nixos-control-center im gesamten squashfs..."
    find "$SQUASHFS_MOUNT" -name "*nixos-control-center*" -type d 2>/dev/null | head -10 || echo "Nichts gefunden"
fi

echo ""
echo "=== Calamares Config ==="
echo ""

# Prüfe settings.conf
echo "5. Prüfe Calamares settings.conf..."
SETTINGS_FILE=$(find "$SQUASHFS_MOUNT" -path "*/calamares-nixos-extensions*/etc/calamares/settings.conf" 2>/dev/null | head -1)
if [ -n "$SETTINGS_FILE" ]; then
    echo "settings.conf gefunden: $SETTINGS_FILE"
    echo ""
    echo "modules-search:"
    grep -A 5 "modules-search:" "$SETTINGS_FILE" 2>/dev/null || echo "nicht gefunden"
    echo ""
    echo "sequence (show):"
    grep -A 20 "show:" "$SETTINGS_FILE" 2>/dev/null | head -25 || echo "nicht gefunden"
    echo ""
    echo "sequence (exec):"
    grep -A 20 "exec:" "$SETTINGS_FILE" 2>/dev/null | head -25 || echo "nicht gefunden"
else
    echo "⚠️  settings.conf nicht gefunden im squashfs"
    echo "Suche nach settings.conf..."
    find "$SQUASHFS_MOUNT" -name "settings.conf" -path "*/calamares*" 2>/dev/null | head -5
fi

# Prüfe modules.conf
echo ""
echo "modules.conf:"
if [ -f "$MOUNT_POINT/etc/calamares/modules.conf" ]; then
    echo "→ Auf ISO: $MOUNT_POINT/etc/calamares/modules.conf"
    cat "$MOUNT_POINT/etc/calamares/modules.conf"
    echo ""
fi

MODULES_FILE=$(find "$SQUASHFS_MOUNT" -path "*/calamares-nixos-extensions*/etc/calamares/modules.conf" 2>/dev/null | head -1)
if [ -n "$MODULES_FILE" ]; then
    echo "→ Im Package: $MODULES_FILE"
    cat "$MODULES_FILE"
    echo ""
fi

echo ""
echo "=== Vergleich ==="
echo ""
echo "5. Vergleich Standard vs. Unsere Module..."
echo ""
echo "Standard-Module haben typischerweise:"
echo "- module.desc (Pflicht)"
echo "- Python-Script für job-Module"
echo "- QML + Python für viewqml-Module"
echo ""
echo "Prüfe unsere Module auf Vollständigkeit..."

# Prüfe ob unsere Module alle benötigten Dateien haben
echo ""
echo "=== Vollständigkeitsprüfung ==="
for module in nixos-control-center nixos-control-center-job; do
    module_path="$MOUNT_POINT/usr/lib/calamares/modules/$module"
    if [ -L "$module_path" ]; then
        real_path=$(readlink -f "$module_path")
    else
        real_path="$module_path"
    fi
    
    if [ -d "$real_path" ]; then
        echo ""
        echo "Module: $module"
        echo "Pfad: $real_path"
        [ -f "$real_path/module.desc" ] && echo "✓ module.desc" || echo "❌ module.desc fehlt"
        [ -f "$real_path/${module}.py" ] && echo "✓ ${module}.py" || echo "❌ ${module}.py fehlt"
        if [ "$module" = "nixos-control-center" ]; then
            [ -f "$real_path/ui.qml" ] && echo "✓ ui.qml" || echo "❌ ui.qml fehlt"
            [ -f "$real_path/${module}.conf" ] && echo "✓ ${module}.conf" || echo "⚠️  ${module}.conf (optional)"
        fi
    fi
done

echo ""
echo "=== Debug abgeschlossen ==="
echo ""
echo "Aufräumen mit: sudo umount $SQUASHFS_MOUNT && sudo umount $MOUNT_POINT"
