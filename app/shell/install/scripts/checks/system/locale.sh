#!/usr/bin/env bash

check_locale() {
    log_section "Detecting System Locale Configuration"

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
    log_info "  Locale: ${system_locale:-not set}"
    log_info "  Timezone: ${timezone:-not set}"
    log_info "  Keyboard Layout: ${keyboard_layout:-not set}"
    [ -n "$keyboard_options" ] && log_info "  Keyboard Options: ${keyboard_options}"

    # Export für weitere Verarbeitung
    export SYSTEM_LOCALE="$system_locale"
    export SYSTEM_TIMEZONE="$timezone"
    export SYSTEM_KEYBOARD_LAYOUT="$keyboard_layout"
    export SYSTEM_KEYBOARD_OPTIONS="$keyboard_options"
    
    return 0
}

# Export functions
export -f check_locale