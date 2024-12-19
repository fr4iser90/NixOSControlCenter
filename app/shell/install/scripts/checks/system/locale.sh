#!/usr/bin/env bash


log_section "Detecting System Locale Configuration"

# System Language & Locale
log_info "System Language Settings:"
current_locale=$(locale | grep LANG= | cut -d= -f2 | tr -d '"')
echo -e "  Language : ${CYAN}${current_locale:-not set}${NC}"

# Get all locale variables
echo -e "  Variables:"
locale | grep -E "LC_" | sort | while read -r line; do
    name=$(echo "$line" | cut -d= -f1)
    value=$(echo "$line" | cut -d= -f2 | tr -d '"')
    if [ -n "$value" ]; then
        echo -e "    ${GRAY}${name}${NC} = ${CYAN}${value}${NC}"
    else
        echo -e "    ${GRAY}${name}${NC} = ${YELLOW}(unset)${NC}"
    fi
done

# Timezone
log_info "Timezone Configuration:"
if [ -L "/etc/localtime" ]; then
    real_tz=$(readlink -f /etc/localtime)
    if echo "$real_tz" | grep -q "zoneinfo"; then
        current_tz=$(echo "$real_tz" | grep -o 'zoneinfo/.*' | cut -d'/' -f2-)
        echo -e "  Timezone : ${CYAN}${current_tz}${NC}"
    else
        echo -e "  Timezone : ${YELLOW}Using host timezone${NC}"
    fi
    current_time=$(date +"%H:%M:%S %Z (%z)")
    echo -e "  Time    : ${GRAY}${current_time}${NC}"
else
    echo -e "  ${RED}No timezone configured${NC}"
fi

# Keyboard Layout
log_info "Keyboard Configuration:"
if command -v localectl &> /dev/null; then
    echo -e "  Console:"
    vconsole_layout=$(localectl status | grep "VC Keymap" | cut -d: -f2 | tr -d ' ')
    if [ -n "$vconsole_layout" ]; then
        echo -e "    Keymap : ${CYAN}${vconsole_layout}${NC}"
    else
        echo -e "    Keymap : ${YELLOW}(unset)${NC}"
    fi
    
    echo -e "  X11:"
    x11_layout=$(localectl status | grep "X11 Layout" | cut -d: -f2 | tr -d ' ')
    x11_model=$(localectl status | grep "X11 Model" | cut -d: -f2 | tr -d ' ')
    x11_variant=$(localectl status | grep "X11 Variant" | cut -d: -f2 | tr -d ' ')
    x11_options=$(localectl status | grep "X11 Options" | cut -d: -f2 | tr -d ' ')
    
    if [ -n "$x11_layout" ]; then
        echo -e "    Layout  : ${CYAN}${x11_layout}${NC}"
        [ -n "$x11_model" ] && echo -e "    Model   : ${CYAN}${x11_model}${NC}"
        [ -n "$x11_variant" ] && echo -e "    Variant : ${CYAN}${x11_variant}${NC}"
        [ -n "$x11_options" ] && echo -e "    Options : ${CYAN}${x11_options}${NC}"
    else
        echo -e "    ${YELLOW}No X11 keyboard configuration found${NC}"
    fi
else
    echo -e "  ${YELLOW}localectl not available${NC}"
fi

# Character Encoding
log_info "Character Encoding:"
encoding=$(locale charmap)
echo -e "  Encoding: ${CYAN}${encoding:-not set}${NC}"