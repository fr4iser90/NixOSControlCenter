#!/bin/bash

# Rebuild menu
rebuild_menu() {
    while true; do
        echo ""
        echo "Rebuild Options:"
        echo "1) Validate Configuration"
        echo "2) Rebuild System"
        echo "3) Back to Main Menu"
        echo ""
        
        read -p "Select an option: " choice
        
        case $choice in
            1)
                if validate_configuration; then
                    log "Configuration validation successful"
                fi
                ;;
            2)
                if rebuild_system; then
                    log "System rebuild successful"
                fi
                ;;
            3)
                break
                ;;
            *)
                log "Invalid option"
                ;;
        esac
    done
}

