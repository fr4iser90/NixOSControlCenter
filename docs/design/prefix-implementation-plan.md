# Präfix-Implementation Plan: [System] Desktop statt Header

## 🎯 ZIEL

**Statt:**
```
🖥️  System Presets
  Desktop
  Server
```

**Jetzt:**
```
[System] Desktop
[System] Server
[Device] Jetson Nano
```

**KEINE Header, KEINE Emojis, nur Präfixe!**

---

## 📋 ZENTRALE FUNKTIONEN

### 1. Neue Datei: `shell/scripts/ui/prompts/formatting/list-formatter.sh`

```bash
#!/usr/bin/env bash

# Format item with prefix
format_item_with_prefix() {
    local category="$1"  # "System", "Device", "Desktop Environment", etc.
    local item="$2"      # "Desktop", "Server", "plasma", etc.
    
    echo "[$category] $item"
}

# Build formatted list from array
build_formatted_list() {
    local category="$1"
    shift
    local items=("$@")
    
    local formatted_list=""
    for item in "${items[@]}"; do
        formatted_list+="$(format_item_with_prefix "$category" "$item")\n"
    done
    
    printf "%b" "$formatted_list"
}

# Remove prefix from selection
remove_prefix() {
    local selection="$1"
    # Remove [Category] prefix
    echo "$selection" | sed 's/^\[.*\] //'
}

# Extract category from selection (for validation)
extract_category() {
    local selection="$1"
    # Extract [Category] from selection
    echo "$selection" | sed -n 's/^\[\(.*\)\].*/\1/p'
}

export -f format_item_with_prefix
export -f build_formatted_list
export -f remove_prefix
export -f extract_category
```

---

## 🔧 IMPLEMENTIERUNG: Alle Stellen

### STELLE 1: Preset Selection (`setup-mode.sh`)

**Aktuell:**
```bash
preset_list+="🖥️  System Presets\n"
for preset in "${SYSTEM_PRESETS[@]}"; do
    preset_list+="  $preset\n"
done
```

**Neu:**
```bash
source "$UI_DIR/prompts/formatting/list-formatter.sh"

# System Presets mit Präfix
for preset in "${SYSTEM_PRESETS[@]}"; do
    preset_list+="$(format_item_with_prefix "System" "$preset")\n"
done

# Device Presets mit Präfix
for preset in "${DEVICE_PRESETS[@]}"; do
    preset_list+="$(format_item_with_prefix "Device" "$preset")\n"
done
```

**Parsing:**
```bash
# Präfix entfernen
preset_choice=$(remove_prefix "$preset_choice")

# Validierung
if ! printf "%s\n" "${SYSTEM_PRESETS[@]}" "${DEVICE_PRESETS[@]}" | grep -q "^${preset_choice}$"; then
    log_error "Invalid preset selected"
    return 1
fi
```

---

### STELLE 2: Custom Install Features (`setup-mode.sh`)

**Aktuell:**
```bash
for group in "${FEATURE_GROUPS[@]}"; do
    group_name="${group%%:*}"
    group_features="${group#*:}"
    feature_list+="$group_name\n"
    IFS='|' read -ra features <<< "$group_features"
    for feature in "${features[@]}"; do
        feature_list+="  $feature\n"
    done
done
```

**Neu:**
```bash
source "$UI_DIR/prompts/formatting/list-formatter.sh"

# Kategorie-Mapping (ohne Emojis!)
declare -A CATEGORY_NAMES=(
    ["Desktop Environment"]="Desktop Environment"
    ["Development"]="Development"
    ["Gaming & Media"]="Gaming & Media"
    ["Containerization"]="Containerization"
    ["Services"]="Services"
    ["Virtualization"]="Virtualization"
)

for group in "${FEATURE_GROUPS[@]}"; do
    group_name="${group%%:*}"
    group_features="${group#*:}"
    
    # Emoji entfernen aus group_name
    clean_group_name=$(echo "$group_name" | sed 's/^[🖥️📦🎮🐳💾] *//')
    
    IFS='|' read -ra features <<< "$group_features"
    for feature in "${features[@]}"; do
        feature_list+="$(format_item_with_prefix "$clean_group_name" "$feature")\n"
    done
done
```

**Parsing:**
```bash
while IFS= read -r choice; do
    # Präfix entfernen
    clean_choice=$(remove_prefix "$choice")
    
    # Nur Features (keine Headers - gibt es nicht mehr!)
    [[ -n "$clean_choice" ]] && selected_features+=("$clean_choice")
done <<< "$feature_choices_string"
```

---

### STELLE 3: FEATURE_GROUPS Definition (`setup-options.sh`)

**Aktuell:**
```bash
FEATURE_GROUPS=(
    "🖥️  Desktop Environment:plasma|gnome|xfce"
    "📦 Development:web-dev|game-dev|python-dev|system-dev"
    ...
)
```

**Neu:**
```bash
FEATURE_GROUPS=(
    "Desktop Environment:plasma|gnome|xfce"
    "Development:web-dev|game-dev|python-dev|system-dev"
    "Gaming & Media:streaming|emulation"
    "Containerization:docker|docker-rootless|podman"
    "Services:database|web-server|mail-server"
    "Virtualization:qemu-vm|virt-manager"
)
```

**KEINE Emojis mehr!**

---

## 📝 CHECKLISTE: Alle Dateien

### Dateien die geändert werden müssen:

1. ✅ **`shell/scripts/ui/prompts/formatting/list-formatter.sh`** → NEU ERSTELLEN
   - `format_item_with_prefix()`
   - `build_formatted_list()`
   - `remove_prefix()`
   - `extract_category()`

2. ✅ **`shell/scripts/ui/prompts/setup-mode.sh`**
   - Preset Selection: Präfix statt Header
   - Custom Install: Präfix statt Header
   - Parsing: Präfix entfernen

3. ✅ **`shell/scripts/ui/prompts/setup-options.sh`**
   - `FEATURE_GROUPS`: Emojis entfernen
   - Arrays bleiben gleich

4. ✅ **`shell/scripts/core/imports.sh`**
   - `list-formatter.sh` importieren

---

## 🎯 IMPLEMENTIERUNGS-SCHRITTE

### Schritt 1: Zentrale Funktionen erstellen
- Erstelle `list-formatter.sh`
- Funktionen: `format_item_with_prefix`, `remove_prefix`

### Schritt 2: Preset Selection umbauen
- `setup-mode.sh` Zeile 26-68
- Header entfernen
- Präfix hinzufügen
- Parsing anpassen

### Schritt 3: Custom Install umbauen
- `setup-mode.sh` Zeile 166-213
- Header entfernen
- Präfix hinzufügen
- Parsing anpassen

### Schritt 4: FEATURE_GROUPS bereinigen
- `setup-options.sh` Zeile 66-73
- Emojis entfernen

### Schritt 5: Imports anpassen
- `imports.sh`
- `list-formatter.sh` importieren

---

## ✅ ERGEBNIS

**Vorher:**
```
🖥️  System Presets
  Desktop
  Server
```

**Nachher:**
```
[System] Desktop
[System] Server
[Device] Jetson Nano
```

**Vorteile:**
- ✅ Keine Header-Probleme
- ✅ Keine Emojis
- ✅ Klare Gruppierung
- ✅ Einfach zu parsen
- ✅ Zentrale Funktionen (nicht überall einzeln)

