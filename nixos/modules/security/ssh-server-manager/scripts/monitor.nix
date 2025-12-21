{ config, lib, pkgs, cfg, ... }:

with lib;

let
  # monitorCfg.monitor is passed from parent module
  monitorCfg = monitorCfg.monitor or {};
  ui = config.core.management.system-manager.submodules.cli-formatter.api;

  monitorScript = pkgs.writeScriptBin "ssh-monitor" ''
    #!${pkgs.bash}/bin/bash

    LOCKFILE="/tmp/ssh-monitor.lock"
    exec 200>"$LOCKFILE"
    if ! flock -n 200; then
      ${ui.messages.error "Another instance is running."}
      exit 1
    fi

    ${ui.messages.loading "Starting SSH connection monitoring..."}

    # Initialize connection tracking
    declare -A CONNECTIONS
    ACTIVE=0
    TOTAL=0

    # Start monitoring SSH connections
    ${pkgs.systemd}/bin/journalctl -f -u sshd | while read -r line; do
      # Connection established
      if echo "$line" | grep -q "Accepted \(password\|publickey\|keyboard-interactive\) for"; then
        USER=$(echo "$line" | grep -oP "for \K[^ ]+")
        IP=$(echo "$line" | grep -oP "from \K[^ ]+")
        METHOD=$(echo "$line" | grep -oP "Accepted \K[^ ]+")
        
        ACTIVE=$((ACTIVE + 1))
        TOTAL=$((TOTAL + 1))
        CONNECTIONS["$USER@$IP"]="$METHOD"
        
        ${ui.messages.success "New SSH connection: $USER@$IP ($METHOD)"}
        ${ui.tables.update "ssh-status" "Active Connections" "$ACTIVE"}
        ${ui.tables.update "ssh-status" "Total Connections" "$TOTAL"}
      fi
      
      # Disconnected
      if echo "$line" | grep -q "Disconnected from"; then
        USER=$(echo "$line" | grep -oP "Disconnected from user \K[^ ]+")
        IP=$(echo "$line" | grep -oP "Disconnected from [^ ]+ port [^ ]+ \K\[.*?\]" | tr -d '[]')
        
        if [ -n "$USER" ] && [ -n "$IP" ]; then
          ACTIVE=$((ACTIVE - 1))
          unset CONNECTIONS["$USER@$IP"]
          
          ${ui.messages.info "SSH disconnected: $USER@$IP"}
          ${ui.tables.update "ssh-status" "Active Connections" "$ACTIVE"}
        fi
      fi

      # Failed attempts
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
          ${ui.messages.warning "Failed SSH attempt: $USER@$IP ($REASON)"}
          ${ui.tables.update "ssh-status" "Failed Attempts" "$((FAILED + 1))"}
        fi
      fi
    done
  '';
in {
  options.features.security.ssh-server-manager.monitor = {
    enable = mkEnableOption "SSH connection monitoring";
    
    logLevel = mkOption {
      type = types.enum ["minimal" "normal" "verbose"];
      default = "normal";
      description = "Level of detail for monitoring logs";
    };
  };

  config = mkIf monitorCfg.enable {
    environment.systemPackages = [ monitorScript ];

    core.management.system-manager.submodules.cli-registry.commands = [
      {
        name = "ssh-monitor";
        description = "Monitor SSH connections in real-time";
        category = "monitoring";
        script = "${monitorScript}/bin/ssh-monitor";
        dependencies = [ "systemd" ];
        shortHelp = "ssh-monitor - Monitor SSH connections";
        longHelp = ''
          Monitors SSH connections in real-time, tracking active connections,
          total connections, and failed attempts. Integrates with the terminal UI.
        '';
      }
    ];
  };
}
