{ config, lib, pkgs, cfg, ... }:

with lib;

let
  # monitoringCfg.monitoring is passed from parent module
  monitoringCfg = monitoringCfg.monitoring or {};
  
  monitorScript = pkgs.writeScriptBin "ssh-monitor" ''
    #!${pkgs.bash}/bin/bash
    
    # Initialize counters and connection tracking
    ACTIVE_CONNECTIONS=$(ss -tn state established '( dport = :ssh )' | wc -l)
    CONNECTIONS=$(ss -tn state established '( dport = :ssh )' | awk '{print $5}' | sort | uniq -c)
    
    # Enhanced SSH Log Monitor with configurable verbosity
    LOG_LEVEL="${toString monitoringCfg.logLevel}"
    ${pkgs.systemd}/bin/journalctl -f -u sshd | while read -r line; do
      if [ "$LOG_LEVEL" = "verbose" ]; then
        logger -t ssh-monitor "Raw log: $line"
      fi
      # Connection established
      if echo "$line" | grep -q "Accepted \(password\|publickey\|keyboard-interactive\) for"; then
        USER=$(echo "$line" | grep -oP "for \K[^ ]+")
        IP=$(echo "$line" | grep -oP "from \K[^ ]+")
        METHOD=$(echo "$line" | grep -oP "Accepted \K[^ ]+")
        
        ACTIVE_CONNECTIONS=$((ACTIVE_CONNECTIONS + 1))
        CONNECTIONS="$CONNECTIONS\n$USER@$IP ($METHOD)"
        
        if [ "${monitoringCfg.notificationLevel}" != "none" ]; then
          ${pkgs.libnotify}/bin/notify-send \
            -i ${pkgs.papirus-icon-theme}/share/icons/Papirus/48x48/status/network-transmit-receive.png \
            "SSH Connected" \
            "User: $USER\nFrom: $IP\nMethod: $METHOD\nActive: $ACTIVE_CONNECTIONS\n\nActive Connections:\n$CONNECTIONS"
        fi
      fi
      
      # Disconnected
      if echo "$line" | grep -q "Disconnected from"; then
        USER=$(echo "$line" | grep -oP "Disconnected from user \K[^ ]+")
        IP=$(echo "$line" | grep -oP "Disconnected from [^ ]+ port [^ ]+ \K\[.*?\]" | tr -d '[]')
        
        if [ -n "$USER" ] && [ -n "$IP" ]; then
          ACTIVE_CONNECTIONS=$((ACTIVE_CONNECTIONS - 1))
          CONNECTIONS=$(echo -e "$CONNECTIONS" | grep -v "$USER@$IP")
          
          if [ "${monitoringCfg.notificationLevel}" != "none" ]; then
            ${pkgs.libnotify}/bin/notify-send \
              -i ${pkgs.papirus-icon-theme}/share/icons/Papirus/48x48/status/network-offline.png \
              "SSH Disconnected" \
              "User: $USER\nFrom: $IP\nActive: $ACTIVE_CONNECTIONS\n\nRemaining Connections:\n$CONNECTIONS"
          fi
        fi
      fi

      # Failed attempts with rate limiting
      if echo "$line" | grep -q "\(Failed password for\|Failed publickey for\|Invalid user\)"; then
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
        
        if [ -n "$USER" ] && [ -n "$IP" ] && [ -n "$REASON" ]; then
          if [ "${monitoringCfg.notificationLevel}" != "none" ]; then
            ${pkgs.libnotify}/bin/notify-send -u critical \
              -i ${pkgs.papirus-icon-theme}/share/icons/Papirus/48x48/status/dialog-warning.png \
              "SSH Failed Attempt!" \
              "Failed login:\nUser: $USER\nFrom: $IP\nReason: $REASON"
          fi
            
          # Log failed attempts to syslog
          logger -t ssh-monitor "Failed SSH attempt: $USER from $IP ($REASON)"
        fi
      fi
    done
  '';
in {
  options.modules.security.ssh-server.monitoring = {
    enable = mkEnableOption "SSH connection monitoring";
    
    logLevel = mkOption {
      type = types.enum ["minimal" "normal" "verbose"];
      default = "normal";
      description = "Level of detail for monitoring logs";
    };
    
    notificationLevel = mkOption {
      type = types.enum ["none" "basic" "detailed"];
      default = "detailed";
      description = "Level of detail for notifications";
    };
    
    logFailedAttempts = mkOption {
      type = types.bool;
      default = true;
      description = "Log failed SSH attempts to syslog";
    };
  };

  config = mkIf monitoringCfg.enable {
    environment.systemPackages = with pkgs; [
      libnotify
      dunst
      papirus-icon-theme
      monitorScript
    ];

    systemd.user.services.ssh-monitor = {
      description = "SSH Connection Monitor";
      wantedBy = [ "default.target" ];
      after = [ "graphical-session.target" ];
      
      serviceConfig = {
        ExecStart = "${monitorScript}/bin/ssh-monitor";
        Restart = "always";
        Environment = [
          "DISPLAY=:0"
          "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
          "XDG_RUNTIME_DIR=/run/user/1000"
        ];
      };
    };
  };
}
