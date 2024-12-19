#!/usr/bin/env bash

log_section "Detecting System Locale Configuration"

get_locale_info() {
    local system_locale
    local timezone
    local keyboard_layout
    local keyboard_options

    # System Locale
    system_locale=$(locale | grep LANG= | cut -d= -f2 | tr -d '"')
    
    # Timezone
    if [ -L "/etc/localtime" ]; then
        real_tz=$(readlink -f /etc/localtime)
        if echo "$real_tz" | grep -q "zoneinfo"; then
            timezone=$(echo "$real_tz" | grep -o 'zoneinfo/.*' | cut -d'/' -f2-)
        fi
    fi

    # Keyboard Layout
    if command -v localectl &> /dev/null; then
        keyboard_layout=$(localectl status | grep "X11 Layout" | cut -d: -f2 | tr -d ' ')
        keyboard_options=$(localectl status | grep "X11 Options" | cut -d: -f2 | tr -d ' ')
    fi

    # Ausgabe
    log_info "System Configuration:"
    log_info "  Locale: ${CYAN}${system_locale:-not set}${NC}"
    log_info "  Timezone: ${CYAN}${timezone:-not set}${NC}"
    log_info "  Keyboard Layout: ${CYAN}${keyboard_layout:-not set}${NC}"
    [ -n "$keyboard_options" ] && log_info "  Keyboard Options: ${CYAN}${keyboard_options}${NC}"

    # Export für weitere Verarbeitung
    export SYSTEM_LOCALE="$system_locale"
    export SYSTEM_TIMEZONE="$timezone"
    export SYSTEM_KEYBOARD_LAYOUT="$keyboard_layout"
    export SYSTEM_KEYBOARD_OPTIONS="$keyboard_options"
}

# Ausführen
get_locale_info