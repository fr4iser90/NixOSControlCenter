#!/usr/bin/env bash

check_locale() {
    log_section "Detecting System Locale Configuration"

    local system_locale
    local timezone
    local keyboard_layout
    local keyboard_options

    # System Locale mit Default
    system_locale=$(locale | grep LANG= | cut -d= -f2 | tr -d '"')
    system_locale=${system_locale:-"en_US.UTF-8"}
    
    # Timezone mit Default
    if [ -L "/etc/localtime" ]; then
        real_tz=$(readlink -f /etc/localtime)
        if echo "$real_tz" | grep -q "zoneinfo"; then
            timezone=$(echo "$real_tz" | grep -o 'zoneinfo/.*' | cut -d'/' -f2-)
        fi
    fi
    : ${timezone:="Europe/Berlin"}  # Default Timezone wenn nicht gesetzt!

    # Keyboard Layout mit Default
    if command -v localectl &> /dev/null; then
        keyboard_layout=$(localectl status | grep "X11 Layout" | cut -d: -f2 | tr -d ' ')
        keyboard_options=$(localectl status | grep "X11 Options" | cut -d: -f2 | tr -d ' ')
    fi
    keyboard_layout=${keyboard_layout:-"us"}

    # Ausgabe mit Hinweis auf Defaults
    log_info "System Configuration:"
    if [ "$system_locale" = "en_US.UTF-8" ] && [ -z "$(locale | grep LANG= | cut -d= -f2 | tr -d '"')" ]; then
        log_info "  Locale: ${system_locale} (default)"
    else
        log_info "  Locale: ${system_locale}"
    fi

    if [ "$timezone" = "Europe/Berlin" ] && [ ! -L "/etc/localtime" ]; then
        log_info "  Timezone: ${timezone} (default)"
    else
        log_info "  Timezone: ${timezone}"
    fi

    if [ "$keyboard_layout" = "us" ] && [ -z "$(localectl status | grep "X11 Layout" | cut -d: -f2 | tr -d ' ')" ]; then
        log_info "  Keyboard Layout: ${keyboard_layout} (default)"
    else
        log_info "  Keyboard Layout: ${keyboard_layout}"
    fi

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