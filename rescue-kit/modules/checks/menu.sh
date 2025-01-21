#!/bin/bash

# Checks menu
checks_menu() {
    while true; do
        clear
        display_header "System Checks"
        display_menu_options "Run All Checks" "Verify System" "Detect Partitions" "Verify Partitions" "List USB Devices" "Back to Main Menu"
        
        check_choice=$(prompt_menu_selection)
        
        case $check_choice in
            1)
                if confirm_action "Are you sure you want to run all system checks?"; then
                    if run_all_checks; then
                        display_success "All checks completed successfully"
                    else
                        display_error "Some checks failed"
                    fi
                fi
                ;;
            2)
                if verify_system; then
                    display_success "System verification successful"
                else
                    display_error "System verification failed"
                fi
                ;;
            3)
                if detect_partitions; then
                    display_success "Partition detection successful"
                else
                    display_error "Partition detection failed"
                fi
                ;;
            4)
                if verify_partitions; then
                    display_success "Partition verification successful"
                else
                    display_error "Partition verification failed"
                fi
                ;;
            5)
                if list_usb_devices; then
                    display_success "USB devices listed successfully"
                else
                    display_error "Failed to list USB devices"
                fi
                ;;
            6)
                break
                ;;
            *)
                display_error "Invalid option"
                ;;
        esac
        
        prompt_continue
    done
}

