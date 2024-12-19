# setup-mode.sh
#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/setup-rules.sh"
source "$(dirname "${BASH_SOURCE[0]}")/validate-mode.sh"
# Setup-Modelle definieren
declare -A SETUP_MODELS=(
    ["Desktop"]="A graphical desktop environment\n\nFeatures:\n- GUI Environment\n- Basic Applications\n- Sound Support\n- Network Manager"
    ["  ├─ Gaming"]="Gaming optimized additions\n\nIncludes:\n- Steam\n- Gamemode\n- Gaming Drivers\n- Performance Tools"
    ["  │  ├─ Streaming"]="Streaming tools and features\n\nIncludes:\n- OBS Studio\n- Discord\n- Streaming Optimizations"
    ["  │  └─ Emulation"]="Retro gaming support\n\nIncludes:\n- RetroArch\n- Common Emulators\n- Controller Support"
    ["  └─ Development"]="Development environment\n\nIncludes:\n- VS Code\n- Git\n- Build Tools\n- Development Libraries"
    ["     ├─ Web"]="Web development stack\n\nIncludes:\n- Node.js\n- Web Servers\n- Database Tools"
    ["     └─ Game"]="Game development tools\n\nIncludes:\n- Game Engines\n- Asset Tools\n- Debug Tools"
    ["Server"]="Headless server setup\n\nFeatures:\n- CLI Only\n- Server Optimizations\n- Remote Management"
    ["  ├─ Docker"]="Container support\n\nIncludes:\n- Docker Engine\n- Docker Compose\n- Container Tools"
    ["  ├─ Web"]="Web server stack\n\nIncludes:\n- Nginx/Apache\n- SSL Support\n- PHP/Python"
    ["  └─ Database"]="Database servers\n\nIncludes:\n- PostgreSQL\n- MySQL\n- Redis"
    ["Homelab Server"]="Pre-configured homelab\n\nFeatures:\n- Media Server\n- Network Services\n- Storage Management"
    ["Custom Setup"]="Custom configuration\n\nFeatures:\n- Full Control\n- Manual Setup\n- Advanced Options"
)

# Definiere die Reihenfolge als Tree
SETUP_ORDER=(
    "Desktop"
    "  ├─ Gaming"
    "  │  ├─ Streaming"
    "  │  └─ Emulation"
    "  └─ Development"
    "     ├─ Web"
    "     └─ Game"
    "Server"
    "  ├─ Docker"
    "  ├─ Web"
    "  └─ Database"
    "Homelab Server"
    "Custom Setup"
)

generate_preview() {
    local selection="$1"
    # Entferne ⛔ Marker falls vorhanden
    selection=$(echo "$selection" | sed 's/^⛔ //')
    local clean_selection=$(echo "$selection" | sed 's/^[ │├└─]*//g')
    
    if is_disabled "$clean_selection"; then
        echo -e "\033[31m❌ Diese Option ist nicht verfügbar mit der aktuellen Auswahl\033[0m"
        return
    fi

    local base_type=""
    
    # Determine system type
    if [[ "$clean_selection" == "Desktop"* ]]; then
        base_type="DESKTOP SYSTEM"
    elif [[ "$clean_selection" == "Server"* ]]; then
        base_type="SERVER SYSTEM"
    elif [[ "$clean_selection" == "Homelab"* ]]; then
        base_type="HOMELAB SERVER"
    else
        base_type="CUSTOM SETUP"
    fi

    # Get dependencies
    local deps=($(activate_dependencies "$clean_selection"))
    local dep_list=""
    for dep in "${deps[@]}"; do
        if [[ "$dep" != "$clean_selection" ]]; then
            dep_list+="• $dep (required)\n"
        fi
    done

    # Generate preview
    cat << EOF
┌────────────────────────────────┐
│ SYSTEM TYPE: $base_type
└────────────────────────────────┘

Description:
${SETUP_MODELS[$selection]}

Selected Module:
• $clean_selection

Required Dependencies:
$dep_list
EOF
}

select_setup_mode() {
    local selected=()
    local current_selection=""
    
    while true; do
        # Erstelle temporäre Liste
        local temp_list=()
        for item in "${SETUP_ORDER[@]}"; do
            clean_item=$(echo "$item" | sed 's/^[ │├└─]*//g')
            local prefix=$(echo "$item" | grep -o '^[ │├└─]*')
            
            if is_disabled "$clean_item"; then
                temp_list+=("$prefix\033[31m$clean_item\033[0m")  # Rot für deaktivierte Optionen
            else
                if [[ " ${selected[*]} " =~ " $clean_item " ]]; then
                    temp_list+=("$prefix\033[32m$clean_item ✓\033[0m")  # Grün mit Häkchen für ausgewählte
                else
                    temp_list+=("$prefix$clean_item")
                fi
            fi
        done

        # FZF Aufruf - mit {+} für direkte Mehrfachauswahl-Anzeige
        current_selection=$(printf "%s\n" "${temp_list[@]}" | fzf \
            --ansi \
            --header="Setup Modus auswählen (SPACE zum Auswählen, ENTER zum Bestätigen)" \
            --preview "echo -e 'Aktuelle Auswahl:\n{+}'" \
            --preview-window="right:50%:wrap" \
            --reverse \
            --bind="space:toggle" \
            --multi \
            --pointer="▶" \
            --prompt="Setup > ")

        [ -z "$current_selection" ] && break

        # Bereinige Auswahl von ANSI-Codes und Markierungen
        clean_selection=$(echo "$current_selection" | sed 's/\x1B\[[0-9;]*[mK]//g' | sed 's/^[ │├└─]*//g' | sed 's/ ✓$//')

        if ! is_disabled "$clean_selection"; then
            if [[ " ${selected[*]} " =~ " $clean_selection " ]]; then
                # Entferne Auswahl
                selected=("${selected[@]/$clean_selection}")
            else
                # Füge Auswahl und Abhängigkeiten hinzu
                mapfile -t deps < <(activate_dependencies "$clean_selection")
                for dep in "${deps[@]}"; do
                    if [[ ! " ${selected[*]} " =~ " $dep " ]]; then
                        selected+=("$dep")
                    fi
                done
            fi
        fi
    done

    # Validiere finale Auswahl
    if ! validate_selection "${selected[@]}"; then
        echo "Ungültige Auswahl. Drücke eine Taste zum Fortfahren..."
        read -n 1
        return 1
    fi

    echo "${selected[*]}"
    return 0
}

# Hilfsfunktionen
is_disabled() {
    local item="$1"
    
    # Basis-Module sind immer verfügbar
    [[ "$item" == "Desktop" || "$item" == "Server" || "$item" == "Custom Setup" ]] && return 1
    
    # Prüfe Server/Desktop Konflikte
    if [[ "$item" == "Server"* && " ${selected[*]} " =~ " Desktop " ]]; then
        return 0
    fi
    
    if [[ "$item" == "Desktop"* && " ${selected[*]} " =~ " Server " ]]; then
        return 0
    fi
    
    return 1
}