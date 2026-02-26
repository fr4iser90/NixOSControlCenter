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
echo ""
echo "4b1. Prüfe /etc/calamares im squashfs..."
if [ -d "$SQUASHFS_MOUNT/etc/calamares" ]; then
    echo "✓ /etc/calamares gefunden im squashfs!"
    echo "Inhalt:"
    ls -la "$SQUASHFS_MOUNT/etc/calamares" 2>/dev/null || echo "Fehler"
    echo ""
    if [ -d "$SQUASHFS_MOUNT/etc/calamares/modules" ]; then
        echo "✓ /etc/calamares/modules gefunden!"
        ls -la "$SQUASHFS_MOUNT/etc/calamares/modules" 2>/dev/null || echo "Fehler"
        for module in nixos-control-center nixos-control-center-job; do
            module_path="$SQUASHFS_MOUNT/etc/calamares/modules/$module"
            if [ -e "$module_path" ]; then
                echo ""
                echo "--- Unser Module: $module (in /etc/calamares/modules) ---"
                echo "Pfad: $module_path"
                if [ -L "$module_path" ]; then
                    echo "→ Symlink zu: $(readlink "$module_path")"
                fi
                ls -la "$module_path" 2>/dev/null || echo "Fehler"
            fi
        done
    else
        echo "❌ /etc/calamares/modules nicht gefunden"
    fi
    if [ -f "$SQUASHFS_MOUNT/etc/calamares/settings.conf" ]; then
        echo ""
        echo "✓ /etc/calamares/settings.conf gefunden!"
        echo "modules-search:"
        grep -A 5 "modules-search:" "$SQUASHFS_MOUNT/etc/calamares/settings.conf" 2>/dev/null | head -10
    else
        echo "❌ /etc/calamares/settings.conf nicht gefunden"
    fi
else
    echo "❌ /etc/calamares nicht gefunden im squashfs"
    echo "Prüfe ob /etc existiert:"
    ls -la "$SQUASHFS_MOUNT/etc" 2>/dev/null | head -10 || echo "/etc existiert nicht im squashfs"
fi

echo ""
echo "4b2. Prüfe /usr/lib/calamares/modules im squashfs..."
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
echo "=== Module-Struktur-Prüfung (Store-Pfade) ==="
echo ""

# Prüfe ob unsere Module module.desc haben (direkt im Store)
for MODULE_PATH in \
  "$SQUASHFS_MOUNT/pskysmzhmzh3fr2lxd9q34r7ic9w7f1v-nixos-control-center-calamares-module" \
  "$SQUASHFS_MOUNT/320xhkfzcrrmimr3r8c0mfx3khv5j47k-nixos-control-center-job-calamares-module"; do
  if [ -d "$MODULE_PATH" ]; then
    MODULE_NAME=$(basename "$MODULE_PATH" | sed 's/-calamares-module$//')
    echo "--- Module: $MODULE_NAME ---"
    echo "Pfad: $MODULE_PATH"
    echo ""
    if [ -f "$MODULE_PATH/module.desc" ]; then
      echo "✅ module.desc vorhanden:"
      cat "$MODULE_PATH/module.desc"
      echo ""
    else
      echo "❌ module.desc FEHLT!"
      echo ""
    fi
    echo "Inhalt:"
    ls -la "$MODULE_PATH" 2>/dev/null | head -15
    echo ""
    echo "---"
    echo ""
  else
    # Versuche alle Varianten zu finden
    FOUND=$(find "$SQUASHFS_MOUNT" -type d -name "*${MODULE_NAME}*calamares-module" 2>/dev/null | head -1)
    if [ -n "$FOUND" ]; then
      echo "--- Module: $MODULE_NAME (gefunden unter anderem Pfad) ---"
      echo "Pfad: $FOUND"
      echo ""
      if [ -f "$FOUND/module.desc" ]; then
        echo "✅ module.desc vorhanden:"
        cat "$FOUND/module.desc"
        echo ""
      else
        echo "❌ module.desc FEHLT!"
        echo ""
      fi
      echo "Inhalt:"
      ls -la "$FOUND" 2>/dev/null | head -15
      echo ""
      echo "---"
      echo ""
    fi
  fi
done

echo ""
echo "=== Calamares settings.conf Vergleich ==="
echo ""

# Prüfe welche settings.conf Calamares verwenden würde
SETTINGS_FILES=$(find "$SQUASHFS_MOUNT" -path "*/calamares-nixos-extensions*/etc/calamares/settings.conf" 2>/dev/null)
if [ -z "$SETTINGS_FILES" ]; then
  echo "⚠️  Keine settings.conf in calamares-nixos-extensions gefunden"
else
  echo "$SETTINGS_FILES" | while read -r SETTINGS; do
    PACKAGE_NAME=$(echo "$SETTINGS" | sed 's|.*/\([^/]*-calamares-nixos-extensions[^/]*\)/.*|\1|')
    echo "--- settings.conf: $PACKAGE_NAME ---"
    echo "Vollständiger Pfad: $SETTINGS"
    echo ""
    echo "modules-search:"
    grep -A 3 "modules-search:" "$SETTINGS" 2>/dev/null | head -5 || echo "nicht gefunden"
    echo ""
    echo "Enthält nixos-control-center in sequence (show)?"
    if grep -A 20 "show:" "$SETTINGS" 2>/dev/null | grep -qi "nixos-control-center"; then
      echo "✅ GEFUNDEN"
      grep -A 20 "show:" "$SETTINGS" 2>/dev/null | grep -i "nixos-control-center"
    else
      echo "❌ NICHT GEFUNDEN"
    fi
    echo ""
    echo "Enthält nixos-control-center-job in sequence (exec)?"
    if grep -A 20 "exec:" "$SETTINGS" 2>/dev/null | grep -qi "nixos-control-center-job"; then
      echo "✅ GEFUNDEN"
      grep -A 20 "exec:" "$SETTINGS" 2>/dev/null | grep -i "nixos-control-center-job"
    else
      echo "❌ NICHT GEFUNDEN"
    fi
    echo ""
    echo "---"
    echo ""
  done
fi

echo ""
echo "=== modules.conf Vergleich ==="
echo ""

# Prüfe alle modules.conf
MODULES_CONF_FILES=$(find "$SQUASHFS_MOUNT" -path "*/calamares-nixos-extensions*/etc/calamares/modules.conf" 2>/dev/null)
if [ -z "$MODULES_CONF_FILES" ]; then
  echo "⚠️  Keine modules.conf in calamares-nixos-extensions gefunden"
else
  echo "$MODULES_CONF_FILES" | while read -r MODULES_CONF; do
    PACKAGE_NAME=$(echo "$MODULES_CONF" | sed 's|.*/\([^/]*-calamares-nixos-extensions[^/]*\)/.*|\1|')
    echo "--- modules.conf: $PACKAGE_NAME ---"
    echo "Vollständiger Pfad: $MODULES_CONF"
    echo ""
    cat "$MODULES_CONF"
    echo ""
    echo "Prüfe ob Module-Pfade existieren:"
    grep "path:" "$MODULES_CONF" 2>/dev/null | sed 's/.*path: *"\([^"]*\)".*/\1/' | while read -r MODULE_STORE_PATH; do
      # Entferne /nix/store/ Präfix für Squashfs-Prüfung
      MODULE_REL_PATH=$(echo "$MODULE_STORE_PATH" | sed 's|^/nix/store/||')
      if [ -d "$SQUASHFS_MOUNT/$MODULE_REL_PATH" ]; then
        echo "✅ $MODULE_STORE_PATH existiert im Squashfs"
      else
        echo "❌ $MODULE_STORE_PATH existiert NICHT im Squashfs"
        echo "   Gesucht unter: $SQUASHFS_MOUNT/$MODULE_REL_PATH"
      fi
    done
    echo ""
    echo "---"
    echo ""
  done
fi

echo ""
echo "=== Zwei-Versionen-Problem ==="
echo ""

# Prüfe ob es immer noch zwei Versionen gibt
CALAMARES_EXTENSIONS=$(find "$SQUASHFS_MOUNT" -type d -name "*-calamares-nixos-extensions-*" 2>/dev/null)
COUNT=$(echo "$CALAMARES_EXTENSIONS" | wc -l)
echo "Gefundene calamares-nixos-extensions Versionen: $COUNT"
if [ "$COUNT" -gt 1 ]; then
  echo "❌ PROBLEM: Es gibt immer noch mehrere Versionen!"
  echo "$CALAMARES_EXTENSIONS" | while read -r EXT_PATH; do
    echo ""
    echo "--- Version: $(basename "$EXT_PATH") ---"
    if [ -f "$EXT_PATH/etc/calamares/modules.conf" ]; then
      echo "✅ Hat modules.conf"
      echo "Inhalt:"
      cat "$EXT_PATH/etc/calamares/modules.conf"
    else
      echo "❌ Hat KEINE modules.conf"
    fi
    echo ""
  done
else
  echo "✅ Nur eine Version gefunden"
fi

echo ""
echo "=== Detaillierte Module-Validierung ==="
echo ""

# Funktion zum Validieren von module.desc
validate_module_desc() {
    local MODULE_PATH="$1"
    local MODULE_NAME="$2"
    local DESC_FILE="$MODULE_PATH/module.desc"
    
    if [ ! -f "$DESC_FILE" ]; then
        echo "❌ module.desc fehlt für $MODULE_NAME"
        return 1
    fi
    
    echo "--- Validierung: $MODULE_NAME ---"
    echo "module.desc Pfad: $DESC_FILE"
    echo ""
    
    # Prüfe ob es YAML ist (beginnt mit --- oder hat : )
    if ! head -1 "$DESC_FILE" | grep -qE "^---|^#"; then
        echo "⚠️  WARNUNG: module.desc sieht nicht wie YAML aus (sollte mit '---' oder '#' beginnen)"
    fi
    
    # Prüfe required fields
    local HAS_TYPE=false
    local HAS_INTERFACE=false
    local HAS_NAME=false
    local HAS_SCRIPT=false
    
    if grep -qE "^type:" "$DESC_FILE"; then
        HAS_TYPE=true
        TYPE_VALUE=$(grep "^type:" "$DESC_FILE" | sed 's/.*type: *"\([^"]*\)".*/\1/' | sed 's/.*type: *\([^ ]*\).*/\1/' | head -1)
        echo "✅ type: $TYPE_VALUE"
    else
        echo "❌ type: FEHLT (required)"
    fi
    
    if grep -qE "^interface:" "$DESC_FILE"; then
        HAS_INTERFACE=true
        INTERFACE_VALUE=$(grep "^interface:" "$DESC_FILE" | sed 's/.*interface: *"\([^"]*\)".*/\1/' | sed 's/.*interface: *\([^ ]*\).*/\1/' | head -1)
        echo "✅ interface: $INTERFACE_VALUE"
    else
        echo "❌ interface: FEHLT (required)"
    fi
    
    if grep -qE "^name:" "$DESC_FILE"; then
        HAS_NAME=true
        NAME_VALUE=$(grep "^name:" "$DESC_FILE" | sed 's/.*name: *"\([^"]*\)".*/\1/' | sed 's/.*name: *\([^ ]*\).*/\1/' | head -1)
        echo "✅ name: $NAME_VALUE"
        
        # Prüfe ob name mit Modul-Name übereinstimmt
        if [ "$NAME_VALUE" != "$MODULE_NAME" ]; then
            echo "⚠️  WARNUNG: name ($NAME_VALUE) stimmt nicht mit Modul-Name ($MODULE_NAME) überein"
        fi
    else
        echo "⚠️  name: FEHLT (empfohlen für besseres Debugging)"
    fi
    
    if grep -qE "^script:" "$DESC_FILE"; then
        HAS_SCRIPT=true
        SCRIPT_VALUE=$(grep "^script:" "$DESC_FILE" | sed 's/.*script: *"\([^"]*\)".*/\1/' | sed 's/.*script: *\([^ ]*\).*/\1/' | head -1)
        echo "✅ script: $SCRIPT_VALUE"
        
        # Prüfe ob Script-Datei existiert
        if [ -f "$MODULE_PATH/$SCRIPT_VALUE" ]; then
            echo "✅ Script-Datei existiert: $SCRIPT_VALUE"
        else
            echo "❌ Script-Datei fehlt: $SCRIPT_VALUE"
        fi
    elif grep -qE "^load:" "$DESC_FILE"; then
        LOAD_VALUE=$(grep "^load:" "$DESC_FILE" | sed 's/.*load: *"\([^"]*\)".*/\1/' | sed 's/.*load: *\([^ ]*\).*/\1/' | head -1)
        echo "✅ load: $LOAD_VALUE (für qtplugin)"
        
        if [ -f "$MODULE_PATH/$LOAD_VALUE" ]; then
            echo "✅ Load-Datei existiert: $LOAD_VALUE"
        else
            echo "❌ Load-Datei fehlt: $LOAD_VALUE"
        fi
    else
        echo "⚠️  script: oder load: FEHLT (benötigt für python/qtplugin)"
    fi
    
    # Prüfe Interface-Konsistenz
    if [ "$HAS_INTERFACE" = true ] && [ "$HAS_SCRIPT" = true ]; then
        if [ "$INTERFACE_VALUE" = "python" ] && [ -n "$SCRIPT_VALUE" ]; then
            echo "✅ Interface 'python' mit 'script:' ist konsistent"
        elif [ "$INTERFACE_VALUE" = "qtplugin" ] && [ -n "$SCRIPT_VALUE" ]; then
            echo "⚠️  WARNUNG: Interface 'qtplugin' sollte 'load:' verwenden, nicht 'script:'"
        fi
    fi
    
    echo ""
}

# Funktion zum Prüfen von Python-Imports
check_python_imports() {
    local MODULE_PATH="$1"
    local MODULE_NAME="$2"
    local PYTHON_FILE="$3"
    
    if [ ! -f "$PYTHON_FILE" ]; then
        return
    fi
    
    echo "--- Python-Import-Check: $MODULE_NAME ---"
    echo "Python-Datei: $PYTHON_FILE"
    echo ""
    
    # Prüfe ob libcalamares importiert wird
    if grep -q "^import libcalamares\|^from libcalamares" "$PYTHON_FILE"; then
        echo "✅ libcalamares wird importiert"
    else
        echo "❌ libcalamares wird NICHT importiert (required für Calamares-Module)"
    fi
    
    # Liste alle Imports
    echo "Gefundene Imports:"
    grep -E "^import |^from " "$PYTHON_FILE" | head -10 || echo "Keine Imports gefunden"
    echo ""
}

# Finde alle unsere Module im Squashfs
echo "Suche nach unseren Modulen im Squashfs..."
CUSTOM_MODULES=$(find "$SQUASHFS_MOUNT" -type d -name "*nixos-control-center*calamares-module" 2>/dev/null)

if [ -z "$CUSTOM_MODULES" ]; then
    echo "❌ Keine Custom-Module gefunden im Squashfs"
else
    echo "$CUSTOM_MODULES" | while read -r MODULE_PATH; do
        MODULE_NAME=$(basename "$MODULE_PATH" | sed 's/-calamares-module$//')
        
        echo ""
        echo "=========================================="
        echo "=== Detaillierte Analyse: $MODULE_NAME ==="
        echo "=========================================="
        echo ""
        
        # Validierung module.desc
        validate_module_desc "$MODULE_PATH" "$MODULE_NAME"
        
        # Prüfe Dateien
        echo "--- Datei-Struktur ---"
        echo "Verzeichnis: $MODULE_PATH"
        echo ""
        echo "Dateien:"
        ls -la "$MODULE_PATH" 2>/dev/null || echo "Fehler beim Auflisten"
        echo ""
        
        # Prüfe Python-Imports
        PYTHON_FILE=$(find "$MODULE_PATH" -name "*.py" -type f | head -1)
        if [ -n "$PYTHON_FILE" ]; then
            check_python_imports "$MODULE_PATH" "$MODULE_NAME" "$PYTHON_FILE"
        fi
        
        # Prüfe ob ui.qml existiert (für viewqml)
        if [ -f "$MODULE_PATH/ui.qml" ]; then
            echo "✅ ui.qml vorhanden (benötigt für viewqml)"
        elif grep -q "type:.*viewqml" "$MODULE_PATH/module.desc" 2>/dev/null; then
            echo "⚠️  ui.qml fehlt (benötigt für viewqml Module)"
        fi
        
        # Prüfe Berechtigungen
        echo "--- Berechtigungen ---"
        if [ -f "$MODULE_PATH/module.desc" ]; then
            DESC_PERMS=$(stat -c "%a %U:%G" "$MODULE_PATH/module.desc" 2>/dev/null || echo "unbekannt")
            echo "module.desc: $DESC_PERMS"
        fi
        if [ -n "$PYTHON_FILE" ]; then
            PYTHON_PERMS=$(stat -c "%a %U:%G" "$PYTHON_FILE" 2>/dev/null || echo "unbekannt")
            echo "$(basename "$PYTHON_FILE"): $PYTHON_PERMS"
            if [ ! -x "$PYTHON_FILE" ]; then
                echo "⚠️  Python-Datei ist nicht ausführbar (sollte +x haben)"
            fi
        fi
        echo ""
        
        echo "---"
        echo ""
    done
fi

echo ""
echo "=== Calamares Module-Loading Simulation ==="
echo ""

# Simuliere wie Calamares Module lädt
MODULES_CONF_FILE=$(find "$SQUASHFS_MOUNT" -path "*/calamares-nixos-extensions*/etc/calamares/modules.conf" 2>/dev/null | head -1)
if [ -n "$MODULES_CONF_FILE" ]; then
    echo "modules.conf: $MODULES_CONF_FILE"
    echo ""
    echo "Calamares würde folgende Module laden:"
    echo ""
    
    # Parse modules.conf und prüfe jeden Eintrag
    grep -E "^[a-z-]+:" "$MODULES_CONF_FILE" | sed 's/:$//' | while read -r MODULE_KEY; do
        MODULE_PATH_LINE=$(grep -A 1 "^$MODULE_KEY:" "$MODULES_CONF_FILE" | grep "path:" | sed 's/.*path: *"\([^"]*\)".*/\1/')
        
        if [ -n "$MODULE_PATH_LINE" ]; then
            echo "Module: $MODULE_KEY"
            echo "  Konfigurierter Pfad: $MODULE_PATH_LINE"
            
            # Konvertiere Store-Pfad zu Squashfs-Pfad
            MODULE_REL_PATH=$(echo "$MODULE_PATH_LINE" | sed 's|^/nix/store/||')
            MODULE_FULL_PATH="$SQUASHFS_MOUNT/$MODULE_REL_PATH"
            
            if [ -d "$MODULE_FULL_PATH" ]; then
                echo "  ✅ Pfad existiert im Squashfs"
                
                # Prüfe module.desc
                if [ -f "$MODULE_FULL_PATH/module.desc" ]; then
                    echo "  ✅ module.desc vorhanden"
                    
                    # Prüfe ob name übereinstimmt
                    MODULE_NAME=$(grep "^name:" "$MODULE_FULL_PATH/module.desc" 2>/dev/null | sed 's/.*name: *"\([^"]*\)".*/\1/' | sed 's/.*name: *\([^ ]*\).*/\1/' | head -1)
                    if [ -n "$MODULE_NAME" ]; then
                        if [ "$MODULE_NAME" = "$MODULE_KEY" ]; then
                            echo "  ✅ name stimmt überein: $MODULE_NAME"
                        else
                            echo "  ⚠️  name ($MODULE_NAME) stimmt nicht mit Key ($MODULE_KEY) überein"
                        fi
                    fi
                else
                    echo "  ❌ module.desc FEHLT"
                fi
                
                # Prüfe Script/Load
                SCRIPT=$(grep "^script:" "$MODULE_FULL_PATH/module.desc" 2>/dev/null | sed 's/.*script: *"\([^"]*\)".*/\1/' | sed 's/.*script: *\([^ ]*\).*/\1/' | head -1)
                LOAD=$(grep "^load:" "$MODULE_FULL_PATH/module.desc" 2>/dev/null | sed 's/.*load: *"\([^"]*\)".*/\1/' | sed 's/.*load: *\([^ ]*\).*/\1/' | head -1)
                
                if [ -n "$SCRIPT" ]; then
                    if [ -f "$MODULE_FULL_PATH/$SCRIPT" ]; then
                        echo "  ✅ Script vorhanden: $SCRIPT"
                    else
                        echo "  ❌ Script fehlt: $SCRIPT"
                    fi
                elif [ -n "$LOAD" ]; then
                    if [ -f "$MODULE_FULL_PATH/$LOAD" ]; then
                        echo "  ✅ Load-Datei vorhanden: $LOAD"
                    else
                        echo "  ❌ Load-Datei fehlt: $LOAD"
                    fi
                else
                    echo "  ⚠️  Kein script: oder load: in module.desc"
                fi
            else
                echo "  ❌ Pfad existiert NICHT im Squashfs"
                echo "     Gesucht unter: $MODULE_FULL_PATH"
            fi
            echo ""
        fi
    done
else
    echo "⚠️  Keine modules.conf gefunden"
fi

echo ""
echo "=== Debug abgeschlossen ==="
echo ""
echo "=== /etc Derivation Diagnose ==="
echo ""

# Finde etc-Derivation mit /etc/calamares
# Es gibt mehrere *-etc Derivationen (fontconfig-etc, system-etc, etc.)
# Wir suchen die mit /etc/calamares
ETC_DERIV=$(find "$SQUASHFS_MOUNT" -maxdepth 1 -type d -name "*-etc" 2>/dev/null | while read -r etc_dir; do
    if [ -d "$etc_dir/etc/calamares" ]; then
        echo "$etc_dir"
        break
    fi
done)

if [ -n "$ETC_DERIV" ]; then
    echo "✅ etc-Derivation gefunden: $ETC_DERIV"
    echo ""
    
    # Prüfe modules.conf
    if [ -f "$ETC_DERIV/etc/calamares/modules.conf" ]; then
        echo "✅ modules.conf in etc-Derivation:"
        echo "---"
        cat "$ETC_DERIV/etc/calamares/modules.conf"
        echo "---"
    else
        echo "❌ modules.conf NICHT in etc-Derivation"
    fi
    echo ""
    
    # Prüfe settings.conf
    if [ -f "$ETC_DERIV/etc/calamares/settings.conf" ]; then
        echo "✅ settings.conf in etc-Derivation"
        echo ""
        echo "--- modules-search Sektion: ---"
        grep -A 10 "modules-search:" "$ETC_DERIV/etc/calamares/settings.conf" 2>/dev/null || echo "modules-search nicht gefunden"
        echo "---"
    else
        echo "❌ settings.conf NICHT in etc-Derivation"
    fi
else
    echo "❌ Keine etc-Derivation gefunden"
fi

echo ""
echo "=== MODULE CONFIG FILES CHECK (/etc/calamares/modules/) ==="
echo ""

# CRITICAL: Prüfe ob nixos-control-center.yaml in /etc/calamares/modules/ ist!
if [ -n "$ETC_DERIV" ]; then
    if [ -d "$ETC_DERIV/etc/calamares/modules" ]; then
        echo "✅ /etc/calamares/modules/ existiert in etc-Derivation"
        echo ""
        echo "Dateien in /etc/calamares/modules/:"
        ls -la "$ETC_DERIV/etc/calamares/modules/" 2>/dev/null || echo "Fehler beim Auflisten"
        echo ""
        
        # Prüfe unsere Config
        if [ -f "$ETC_DERIV/etc/calamares/modules/nixos-control-center.yaml" ]; then
            echo "✅✅✅ ERFOLG: nixos-control-center.yaml GEFUNDEN!"
            echo ""
            echo "Inhalt:"
            echo "---"
            cat "$ETC_DERIV/etc/calamares/modules/nixos-control-center.yaml"
            echo "---"
        else
            echo "❌❌❌ FEHLER: nixos-control-center.yaml NICHT GEFUNDEN!"
            echo "Module-Config muss in /etc/calamares/modules/ sein!"
        fi
        
        # Prüfe ob .conf Dateien im Modul-Verzeichnis sind (sollte nicht sein!)
        echo ""
        echo "=== Prüfe Modul-Verzeichnisse auf .conf/.yaml Dateien ==="
        CUSTOM_MODULES_DIR=$(grep "custom-calamares-modules" "$ETC_DERIV/etc/calamares/settings.conf" 2>/dev/null | sed 's/.*\/nix\/store\/\([^\/]*-custom-calamares-modules\).*/\1/' | head -1)
        
        if [ -n "$CUSTOM_MODULES_DIR" ]; then
            MODULE_PATH="$SQUASHFS_MOUNT/$CUSTOM_MODULES_DIR/nixos-control-center"
            if [ -d "$MODULE_PATH" ]; then
                echo "Module-Verzeichnis: $MODULE_PATH"
                echo ""
                
                CONF_FILES=$(find "$MODULE_PATH" -maxdepth 1 \( -name "*.conf" -o -name "*.yaml" \) -type f 2>/dev/null)
                if [ -n "$CONF_FILES" ]; then
                    echo "❌❌❌ PROBLEM: .conf/.yaml Dateien im Modul-Verzeichnis gefunden:"
                    echo "$CONF_FILES"
                    echo "Diese Dateien sollten NICHT im Modul-Verzeichnis sein!"
                    echo "Sie verursachen das @ Problem!"
                else
                    echo "✅✅✅ ERFOLG: KEINE .conf/.yaml Dateien im Modul-Verzeichnis!"
                fi
            fi
        fi
    else
        echo "❌ /etc/calamares/modules/ existiert NICHT in etc-Derivation!"
    fi
fi

echo ""
echo "Aufräumen mit: sudo umount $SQUASHFS_MOUNT && sudo umount $MOUNT_POINT"
