{ config, lib, pkgs, systemConfig, ... }:

let
  ssh-manager = pkgs.writeScriptBin "ssh-manager" ''
    #!${pkgs.bash}/bin/bash
    
    CREDS_FILE="$HOME/.creds"

    load_saved_servers() {
        if [[ -f "$CREDS_FILE" ]]; then
            cat "$CREDS_FILE"
        else
            echo "Credentials file not found. Creating a new one."
            touch "$CREDS_FILE"
        fi
    }

    save_new_server() {
        local server_ip="$1"
        local username="$2"
        echo "$server_ip=$username" >> "$CREDS_FILE"
        echo "New server saved."
    }

    get_user_input() {
        local prompt="$1"
        read -rp "$prompt" input
        echo "$input"
    }

    select_server() {
        local servers_list="$1"
        local options=("Add new server")
        while IFS='=' read -r ip user; do
            options+=("$ip ($user)")
        done <<< "$servers_list"
        printf '%s\n' "''${options[@]}" | ${pkgs.fzf}/bin/fzf --prompt="Select a saved server or add a new one: "
    }

    connect_to_server() {
        local full_server="$1"
        ${pkgs.openssh}/bin/ssh "$full_server"
    }

    add_ssh_key() {
        local username="$1"
        local server="$2"
        if [[ ! -f "$HOME/.ssh/id_rsa.pub" ]]; then
            echo "SSH key not found. Generating a new SSH key."
            ${pkgs.openssh}/bin/ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/id_rsa" -N ""
        fi
        ${pkgs.openssh}/bin/ssh-copy-id "$username@$server"
    }

    connect_server() {
        local servers_list; servers_list=$(load_saved_servers)

        echo "DEBUG: Servers list loaded - $servers_list"

        local choice; choice=$(select_server "$servers_list")

        echo "DEBUG: Choice selected - $choice"

        local server
        local username

        if [[ "$choice" == "Add new server" ]]; then
            server=$(get_user_input "Enter the new server IP: ")
            echo "DEBUG: New server IP - $server"
            username=$(get_user_input "Enter the username for the new server: ")
            echo "DEBUG: New server username - $username"
            if [[ $(get_user_input "Do you want to save this server? (yes/no): ") == "yes" ]]; then
                save_new_server "$server" "$username"
            fi
        else
            server="''${choice%% (*)}"
            username="''${choice##*(}"
            username="''${username%)*}"
        fi

        echo "DEBUG: Server - $server, Username - $username"

        add_ssh_key "$username" "$server"
        connect_to_server "$username@$server"
    }

    main() {
        if ! command -v ${pkgs.fzf}/bin/fzf &> /dev/null; then
            echo "fzf not found. Please install fzf to use this script." >&2
            exit 1
        fi
        connect_server
    }

    main
  '';

  # Erstelle einen Wrapper für ssh-connect
  ssh-connect = pkgs.writeScriptBin "ssh-connect" ''
    #!${pkgs.bash}/bin/bash
    exec ${ssh-manager}/bin/ssh-manager "$@"
  '';

in {
  config = {
    environment.systemPackages = [ 
      ssh-manager
      ssh-connect  # Füge den Wrapper hinzu
      pkgs.fzf
      pkgs.openssh
    ];
    
    # Erstelle .creds nur für konfigurierte Benutzer
    system.activationScripts.sshManagerSetup = let
      configuredUsers = lib.attrNames systemConfig.users;
      setupForUser = user: ''
        if [ ! -f /home/${user}/.creds ]; then
          install -m 600 -o ${user} -g ${user} /dev/null /home/${user}/.creds
        fi
      '';
    in ''
      # Erstelle .creds für konfigurierte Benutzer
      ${lib.concatMapStrings setupForUser configuredUsers}
    '';
  };
}