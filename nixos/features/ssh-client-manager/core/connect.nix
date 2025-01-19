{ config, lib, pkgs, ... }:

let
  ui = config.features.terminal-ui.api;
  connectScript = pkgs.writeScriptBin "ssh-manager" ''
    #!${pkgs.bash}/bin/bash
    
    # Trap for CTRL+C
    trap '${ui.messages.error "Operation cancelled"}; exit 0' INT
    
    ${config.services.ssh-manager.utils}

    connect_to_server() {
        local full_server="$1"
        local test_only="''${2:-false}"
        
        if [[ "$test_only" == "true" ]]; then
            ${pkgs.openssh}/bin/ssh -o BatchMode=yes -o ConnectTimeout=5 "$full_server" exit 2>/dev/null
            return $?
        fi
        
        ${pkgs.openssh}/bin/ssh "$full_server"
    }

    add_ssh_key() {
        local username="$1"
        local server="$2"
        if [[ ! -f "$HOME/.ssh/id_rsa.pub" ]]; then
            ${ui.messages.info "SSH key not found. Generating a new SSH key."}
            ${pkgs.openssh}/bin/ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N ""
        fi
        ${pkgs.openssh}/bin/ssh-copy-id "$username@$server"
    }

    connect_server() {
        local servers_list; servers_list=$(load_saved_servers)

        ${ui.messages.loading "Loading saved servers..."}

        local choice; choice=$(select_server "$servers_list")

        local server
        local username

        if [[ -z "$choice" ]]; then
            ${ui.messages.error "No server selected"}
            exit 0
        fi

        if [[ "$choice" == "Add new server" ]]; then
            ${ui.messages.info "Adding new server"}
            read -p "Enter server IP/hostname: " server
            read -p "Enter username: " username
            
            if [[ -z "$server" || -z "$username" ]]; then
                ${ui.messages.error "Server and username are required"}
                exit 1
            fi
            
            ${ui.messages.loading "Saving new server..."}
            save_new_server "$server" "$username"
            ${ui.messages.success "Server saved successfully"}
        else
            server=$(echo "$choice" | cut -d' ' -f1)
            username=$(echo "$choice" | cut -d'(' -f2 | cut -d')' -f1)
        fi

        ${ui.messages.loading "Connecting to $username@$server..."}
        
        if ! connect_to_server "$username@$server" "true"; then
            ${ui.messages.warning "Connection failed. Trying to add SSH key..."}
            if add_ssh_key "$username" "$server"; then
                ${ui.messages.success "SSH key added successfully. Connecting..."}
                connect_to_server "$username@$server"
            else
                ${ui.messages.error "Failed to add SSH key"}
                exit 1
            fi
        else
            connect_to_server "$username@$server"
        fi
    }

    # Main program
    if ! command -v ${pkgs.fzf}/bin/fzf &> /dev/null; then
        ${ui.messages.error "fzf not found. Please install fzf to use this script."}
        exit 1
    fi
    connect_server
  '';

in {
  config = {
    environment.systemPackages = [ connectScript ];
  };
}
