# Install wizard init — preset-first (no legacy mode setup_*).
{ pkgs, getModuleApi ? null, ... }:
pkgs.writeText "init.sh" ''
#!/usr/bin/env bash
set -euo pipefail

# Source core components
source "$CORE_DIR/imports.sh"

# Parse install flags early (before mutating work)
for arg in "$@"; do
    case "$arg" in
        --dry-run|--dry|dry-run)
            ncc_dry_enable
            ;;
        --help|-h)
            echo "Usage: ncc install [--dry-run]"
            echo "  --dry-run   Preview only — nothing written under /etc/nixos"
            exit 0
            ;;
    esac
done

main() {
    log_header "NixOS System Setup"
    ncc_dry_banner
    
    check_hardware_config
    
    # Collect system information
    collect_system_data || {
        log_error "System data collection failed"
        exit 1
    }
    
    # Get user's setup mode selection
    log_section "Setup Mode"

    # Answers file MUST be created in this shell before $(select_setup_mode):
    # command substitution runs the wizard in a subshell — exports there are lost.
    if declare -F ncc_gui_ensure_answers_file >/dev/null 2>&1; then
        ncc_gui_ensure_answers_file
    fi
    
    if ! selected_modules_raw=$(select_setup_mode); then
        log_error "Setup mode selection failed"
        exit 1
    fi
    
    if [[ -z "$selected_modules_raw" ]]; then
        log_error "No setup mode selected"
        exit 1
    fi
    
    log_info "Selected modules: $selected_modules_raw"
    
    # Check for Advanced Options first (LOAD_BLUEPRINT: / legacy LOAD_PROFILE: / IMPORT_CONFIG:)
    if [[ "$selected_modules_raw" =~ ^LOAD_BLUEPRINT: ]] || [[ "$selected_modules_raw" =~ ^LOAD_PROFILE: ]]; then
        local profile_path="''${selected_modules_raw#LOAD_BLUEPRINT:}"
        profile_path="''${profile_path#LOAD_PROFILE:}"
        apply_install_template "$profile_path" || exit 1
        
    elif [[ "$selected_modules_raw" =~ ^IMPORT_CONFIG: ]]; then
        # Import from existing config
        local config_path="''${selected_modules_raw#IMPORT_CONFIG:}"
        log_info "Importing configuration from: $config_path"
        if [[ -f "$config_path" ]]; then
            if ncc_dry_run; then
                ncc_dry_skip "import config" "$config_path → $SYSTEM_CONFIG_FILE"
                ncc_dry_skip "deploy_config" "/etc/nixos"
            else
                backup_file "$SYSTEM_CONFIG_FILE" 2>/dev/null || true
                ensure_dir "$(dirname "$SYSTEM_CONFIG_FILE")"
                cp "$config_path" "$SYSTEM_CONFIG_FILE" || {
                    log_error "Failed to import configuration"
                    exit 1
                }
                log_success "Configuration imported successfully"
                
                # Export system type for deployment
                local system_type
                system_type=$(grep -m 1 'systemType = ' "$SYSTEM_CONFIG_FILE" | sed 's/.*systemType = "\(.*\)";.*/\1/' || echo "desktop")
                export SYSTEM_TYPE="$system_type"
                deploy_config
            fi
        else
            log_error "Configuration file not found: $config_path"
            exit 1
        fi
        
    # Check if this is a predefined profile (legacy support)
    elif profile_file=$(get_predefined_profile_file "$selected_modules_raw"); then
        # This is a predefined profile - load it directly
        apply_install_template "$profile_file" || exit 1
        
    elif [[ "$selected_modules_raw" == "Desktop" ]]; then
        # Desktop preset - load desktop preset file
        local desktop_preset="$SETUP_DIR/modes/install-bases/desktop.nix"
        if [[ -f "$desktop_preset" ]]; then
            apply_install_template "$desktop_preset" || exit 1
        else
            log_error "Desktop preset not found: $desktop_preset"
            exit 1
        fi
        
    elif [[ "$selected_modules_raw" == "Server" ]]; then
        # Server preset - load server preset file
        local server_preset="$SETUP_DIR/modes/install-bases/server.nix"
        if [[ -f "$server_preset" ]]; then
            apply_install_template "$server_preset" || exit 1
        else
            log_error "Server preset not found: $server_preset"
            exit 1
        fi
        
    elif [[ "$selected_modules_raw" == "Homelab Server" ]]; then
        local homelab_preset="$SETUP_DIR/modes/install-bases/homelab-server.nix"
        if [[ -f "$homelab_preset" ]]; then
            apply_install_template "$homelab_preset" || exit 1
        else
            log_error "Homelab Server preset not found: $homelab_preset"
            exit 1
        fi

    elif [[ "$selected_modules_raw" == "Jetson Nano" || "$selected_modules_raw" == "Fr4iser Jetson Orin Nano" ]]; then
        local jetson_profile="$SETUP_DIR/modes/host-blueprints/fr4iser-jetson-orin"
        if [[ -f "$jetson_profile" ]]; then
            apply_install_template "$jetson_profile" || exit 1
        else
            log_error "Jetson profile not found: $jetson_profile"
            exit 1
        fi

    else
        # From Scratch / custom: systemType + optional package modules → temp preset → apply
        IFS=' ' read -ra selected_modules <<< "$selected_modules_raw"
        local first_selection="''${selected_modules[0]}"

        if [[ "$first_selection" =~ ^(desktop|server)$ ]]; then
            local system_type="$first_selection"
            local packages=( "''${selected_modules[@]:1}" )
            local tmp_preset
            tmp_preset=$(mktemp "''${TMPDIR:-/tmp}/ncc-from-scratch.XXXXXX.nix")
            {
                echo "{"
                echo "  systemType = \"$system_type\";"
                echo "  hostName = null;"
                echo "  system = { channel = \"stable\"; bootloader = \"systemd-boot\"; };"
                echo -n "  packageModules = ["
                local p
                for p in "''${packages[@]}"; do
                    [[ -n "$p" ]] || continue
                    # Desktop envs are not packageModules
                    case "$p" in
                        plasma|gnome|xfce) continue ;;
                    esac
                    echo -n " \"$p\""
                done
                echo " ];"
                # DE from selection
                local de=""
                for p in "''${packages[@]}"; do
                    case "$p" in plasma|gnome|xfce) de="$p" ;; esac
                done
                if [[ -n "$de" ]]; then
                    echo "  desktop = { enable = true; environment = \"$de\"; display = { manager = \"sddm\"; server = \"wayland\"; session = \"$de\"; }; theme = { dark = true; }; audio = \"pipewire\"; };"
                else
                    echo "  desktop = { enable = false; environment = null; display = { manager = null; server = null; session = null; }; theme = { dark = null; }; audio = null; };"
                fi
                echo "  users = {};"
                echo "  hardware = { cpu = null; gpu = null; };"
                echo "  allowUnfree = true;"
                echo "  buildLogLevel = \"minimal\";"
                echo "  features = { ssh-manager = false; stack-manager = false; bootentry-manager = false; vm-manager = false; ai-workspace = false; };"
                echo "  timeZone = \"Europe/Berlin\";"
                echo "  locales = [ \"en_US.UTF-8\" ];"
                echo "  keyboardLayout = \"de\";"
                echo "  overrides = { enableSSH = null; };"
                echo "}"
            } > "$tmp_preset"
            apply_install_template "$tmp_preset" || { rm -f "$tmp_preset"; exit 1; }
            rm -f "$tmp_preset"
        elif [[ "$first_selection" == "Desktop" ]]; then
            apply_install_template "$SETUP_DIR/modes/install-bases/desktop.nix" || exit 1
        elif [[ "$first_selection" == "Server" ]]; then
            apply_install_template "$SETUP_DIR/modes/install-bases/server.nix" || exit 1
        elif [[ "$first_selection" == "Homelab" ]]; then
            apply_install_template "$SETUP_DIR/modes/install-bases/homelab-server.nix" || exit 1
        else
            log_error "Invalid setup type: $first_selection"
            exit 1
        fi
    fi
    
    if ncc_dry_run; then
        log_success "Dry-run OK — safe to run the real install when ready"
        log_next "sudo ncc install"
    else
        log_success "Setup complete"
        log_next "sudo ncc system build switch"
    fi
}

# Map predefined profile names to file names
get_predefined_profile_file() {
    local profile_name="$1"
    local profile_file=""

    case "$profile_name" in
        "Fr4iser Personal Desktop") profile_file="fr4iser-home" ;;
        "Gira Personal Desktop") profile_file="gira-home" ;;
        "Fr4iser Jetson Nano"|"Fr4iser Jetson Orin Nano"|"Jetson Nano")
            profile_file="fr4iser-jetson-orin" ;;
        "Homelab Server")
            local base="$SETUP_DIR/modes/install-bases/homelab-server.nix"
            if [[ -f "$base" ]]; then
                echo "$base"
                return 0
            fi
            return 1
            ;;
        *)
            return 1
            ;;
    esac

    local profile_path="$SETUP_DIR/modes/host-blueprints/$profile_file"
    if [[ -f "$profile_path" ]]; then
        echo "$profile_path"
        return 0
    else
        log_error "Profile file not found: $profile_path"
        return 1
    fi
}

# Execute main function if script is run directly
check_script_execution "CORE_DIR" "main"

''
