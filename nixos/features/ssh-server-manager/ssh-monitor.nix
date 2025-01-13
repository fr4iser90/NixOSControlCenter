{ config, lib, pkgs, ... }:

let
  sshMonitorScript = pkgs.writeScriptBin "ssh-monitor" ''
    #!${pkgs.bash}/bin/bash
    
    # Initialisiere Verbindungszähler aus aktiven SSH-Sitzungen
    ACTIVE_CONNECTIONS=$(w -h | grep -c pts)
    CONNECTIONS=$(w -h | grep pts | awk '{print $1"@"$3}')
    
    # SSH Log Monitor
    ${pkgs.systemd}/bin/journalctl -f -u sshd | while read line; do
      # Connection established
      if echo "$line" | grep -q "Accepted \(password\|publickey\|keyboard-interactive\) for"; then
        USER=$(echo "$line" | grep -oP "for \K[^ ]+")
        IP=$(echo "$line" | grep -oP "from \K[^ ]+")
        METHOD=$(echo "$line" | grep -oP "Accepted \K[^ ]+")
        
        ACTIVE_CONNECTIONS=$((ACTIVE_CONNECTIONS + 1))
        CONNECTIONS="$CONNECTIONS\n$USER@$IP ($METHOD)"
        
        ${pkgs.libnotify}/bin/notify-send \
          -i ${pkgs.papirus-icon-theme}/share/icons/Papirus/48x48/status/network-transmit-receive.png \
          "SSH Connected" \
          "User: $USER\nFrom: $IP\nMethod: $METHOD\nActive: $ACTIVE_CONNECTIONS\n\nActive Connections:\n$CONNECTIONS"
      fi
      
      # Disconnected
      if echo "$line" | grep -q "Disconnected from"; then
        USER=$(echo "$line" | grep -oP "Disconnected from user \K[^ ]+")
        IP=$(echo "$line" | grep -oP "Disconnected from [^ ]+ port [^ ]+ \K\[.*?\]" | tr -d '[]')
        
        if [ ! -z "$USER" ] && [ ! -z "$IP" ]; then
          ACTIVE_CONNECTIONS=$((ACTIVE_CONNECTIONS - 1))
          CONNECTIONS=$(echo -e "$CONNECTIONS" | grep -v "$USER@$IP")
          
          ${pkgs.libnotify}/bin/notify-send \
            -i ${pkgs.papirus-icon-theme}/share/icons/Papirus/48x48/status/network-offline.png \
            "SSH Disconnected" \
            "User: $USER\nFrom: $IP\nActive: $ACTIVE_CONNECTIONS\n\nRemaining Connections:\n$CONNECTIONS"
        fi
      fi

      # Failed attempts
      if echo "$line" | grep -q "\(Failed password for\|Failed publickey for\|Invalid user\)" && ! echo "$line" | grep -q "\(authentication failure\|pam_unix\)"; then
        if echo "$line" | grep -q "Invalid user"; then
          USER=$(echo "$line" | grep -oP "Invalid user \K[^ ]+")
          REASON="invalid user"
        elif echo "$line" | grep -q "Failed password for"; then
          USER=$(echo "$line" | grep -oP "Failed password for \K[^ ]+")
          REASON="wrong password"
        elif echo "$line" | grep -q "Failed publickey for"; then
          USER=$(echo "$line" | grep -oP "Failed publickey for \K[^ ]+")
          REASON="wrong publickey"
        fi
        
        IP=$(echo "$line" | grep -oP "from \K[^ ]+")
        
        if [ ! -z "$USER" ] && [ ! -z "$IP" ] && [ ! -z "$REASON" ]; then
          ${pkgs.libnotify}/bin/notify-send -u critical \
            -i ${pkgs.papirus-icon-theme}/share/icons/Papirus/48x48/status/dialog-warning.png \
            "SSH Failed Attempt!" \
            "Failed login:\nUser: $USER\nFrom: $IP\nReason: $REASON"
        fi
      fi
    done
  '';

in {
  environment.systemPackages = with pkgs; [
    libnotify
    dunst
    papirus-icon-theme
  ];

  systemd.user.services.ssh-monitor = {
    description = "SSH Connection Monitor";
    wantedBy = [ "default.target" ];
    after = [ "graphical-session.target" ];
    
    serviceConfig = {
      ExecStart = "${sshMonitorScript}/bin/ssh-monitor";
      Restart = "always";
      Environment = [
        "DISPLAY=:0"
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
        "XDG_RUNTIME_DIR=/run/user/1000"
      ];
    };
  };
}