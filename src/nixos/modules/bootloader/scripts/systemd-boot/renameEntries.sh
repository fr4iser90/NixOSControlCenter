#!/usr/bin/env bash

# Konstanten
ENTRIES_FILE="/boot/loader/entries/bootloader-entries.json"
SETUP_NAME="${1:-${HOSTNAME}Setup}"
SORT_KEY="${2:-$HOSTNAME}"
SETUP_LIMIT="${3:-5}"

# Validierungsfunktionen
validate_generation() {
    local gen=$1
    [[ "$gen" =~ ^[0-9]+$ ]] || return 1
    return 0
}

validate_name() {
    local name=$1
    [[ "$name" =~ ^[a-zA-Z0-9_-]+$ ]] || return 1
    return 0
}

# JSON Management
update_entries_file() {
    local gen_number=$1
    local title=$2
    local sort_key=$3

    if [ ! -f "$ENTRIES_FILE" ]; then
        echo '{"generations": {}, "lastUpdate": ""}' > "$ENTRIES_FILE"
    fi

    local json_entry=$(jq --arg gen "$gen_number" \
                         --arg title "$title" \
                         --arg sort "$sort_key" \
                         --arg time "$(date -Iseconds)" \
                         '.generations[$gen] = {
                           "title": $title,
                           "sortKey": $sort,
                           "lastUpdate": $time
                         }' "$ENTRIES_FILE")

    echo "$json_entry" > "$ENTRIES_FILE"
}

get_entry_from_file() {
    local gen_number=$1
    jq -r --arg gen "$gen_number" '.generations[$gen] // empty' "$ENTRIES_FILE"
}

# Boot Entry Management
find_latest_generation() {
    local latest=0
    for entry in /boot/loader/entries/nixos-generation-*.conf; do
        if [ -f "$entry" ]; then
            local num=$(basename "$entry" | grep -o '[0-9]\+')
            if [ "$num" -gt "$latest" ]; then
                latest=$num
            fi
        fi
    done
    echo "$latest"
}

count_setup_generations() {
    local sort_key=$1
    find /boot/loader/entries -name 'nixos-generation-*.conf' -exec grep -l "^sort-key $sort_key" {} \; | wc -l
}

rename_entry() {
    local gen_number=$1
    local new_name=$2
    local entry_file="/boot/loader/entries/nixos-generation-$gen_number.conf"

    # Validierung
    if ! validate_generation "$gen_number" || ! validate_name "$new_name"; then
        echo "Error: Invalid generation number or name"
        exit 1
    fi

    if [ ! -f "$entry_file" ] || [ -h "$entry_file" ]; then
        echo "Error: Invalid boot entry file: $entry_file"
        exit 1
    fi

    # Version extrahieren
    local version_line=$(grep "^version" "$entry_file" || echo "")
    local nixos_version=""
    if echo "$version_line" | grep -q "[0-9]\+\.[0-9]\+\.[0-9]\+"; then
        nixos_version=$(echo "$version_line" | grep -o "[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+" || echo "")
    fi

    # Backup erstellen
    cp "$entry_file" "$entry_file.backup"

    # Title aktualisieren
    local title_cmd="s/^title.*/title $new_name/"
    [ -n "$nixos_version" ] && title_cmd="s/^title.*/title $new_name ($nixos_version)/"

    if ! sed -i.tmp "$title_cmd" "$entry_file"; then
        echo "Error: Failed to update title"
        mv "$entry_file.backup" "$entry_file"
        exit 1
    fi

    # Sort-key aktualisieren
    if ! sed -i.tmp "s/^sort-key.*/sort-key $SORT_KEY/" "$entry_file"; then
        echo "Error: Failed to update sort-key"
        mv "$entry_file.backup" "$entry_file"
        exit 1
    fi

    # Cleanup
    rm -f "$entry_file.tmp" "$entry_file.backup"

    # JSON aktualisieren
    update_entries_file "$gen_number" "$new_name" "$SORT_KEY"

    echo "Successfully updated boot entry for generation $gen_number"
}

cleanup_json_entries() {
    echo "Cleaning up JSON entries..."

    # Temporäre JSON erstellen
    local temp_json=$(mktemp)
    jq '.' "$ENTRIES_FILE" > "$temp_json"

    # Alle JSON-Einträge durchgehen und nicht existierende Generationen entfernen
    jq -r '.generations | keys[]' "$ENTRIES_FILE" | while read gen; do
        if [ ! -f "/boot/loader/entries/nixos-generation-${gen}.conf" ]; then
            jq "del(.generations[\"$gen\"])" "$temp_json" > "${temp_json}.new"
            mv "${temp_json}.new" "$temp_json"
        fi
    done

    mv "$temp_json" "$ENTRIES_FILE"
}

sync_all_entries() {
    echo "Synchronizing all boot entries..."

    # Alle Boot-Einträge durchgehen
    for entry in /boot/loader/entries/nixos-generation-*.conf; do
        if [ -f "$entry" ]; then
            local gen_number=$(basename "$entry" | grep -o '[0-9]\+')
            local system_path=$(grep "^options" "$entry" | grep -o "/nix/store/[^/]*-nixos-system-[^/]*/")

            # System-Typ aus Pfad extrahieren
            if [[ "$system_path" =~ -system-([^-]+)- ]]; then
                local system_type="${BASH_REMATCH[1]}"
                local setup_name="${system_type}Setup"
                local sort_key="$system_type"

                # Nur aktualisieren wenn nötig
                if ! grep -q "^sort-key $sort_key" "$entry" || ! grep -q "^title $setup_name" "$entry"; then
                    echo "Updating generation $gen_number to $setup_name"
                    SORT_KEY="$sort_key" rename_entry "$gen_number" "$setup_name"
                fi
            fi
        fi
    done

    # JSON bereinigen
    cleanup_json_entries
}

# Hauptlogik
main() {
    if [ $# -eq 0 ]; then
        latest_gen=$(find_latest_generation)
        if [ "$latest_gen" -gt 0 ]; then
            entry_file="/boot/loader/entries/nixos-generation-$latest_gen.conf"
            if [ -f "$entry_file" ]; then
                local system_path=$(grep "^options" "$entry_file" | grep -o "/nix/store/[^/]*-nixos-system-[^/]*/")
                if [[ "$system_path" =~ -system-([^-]+)- ]]; then
                    local system_type="${BASH_REMATCH[1]}"
                    SETUP_NAME="${system_type}Setup"
                    SORT_KEY="$system_type"
                fi

                if ! grep -q "^sort-key $SORT_KEY" "$entry_file"; then
                    rename_entry "$latest_gen" "$SETUP_NAME"
                fi
            fi
        fi
        # Immer sync ausführen
        sync_all_entries
    elif [ "$1" = "--sync" ]; then
        sync_all_entries
    elif [ "$1" = "--cleanup" ]; then
        cleanup_old_generations "$SORT_KEY" "$SETUP_LIMIT"
        cleanup_json_entries
    elif [ $# -eq 2 ]; then
        rename_entry "$1" "$2"
        sync_all_entries
    else
        echo "Usage: rename-boot-entries [--sync|--cleanup|generation-number new-name]"
        exit 1
    fi
}


main "$@"
