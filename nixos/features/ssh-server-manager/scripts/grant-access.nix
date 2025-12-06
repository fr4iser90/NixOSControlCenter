{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.features.ssh-server-manager.grant-access;
  ui = config.core.cli-formatter.api;

  grantAccessScript = pkgs.writeScriptBin "ssh-grant-access" ''
    #!${pkgs.bash}/bin/bash

    LOCKFILE="/tmp/ssh-grant-access.lock"
    exec 200>"$LOCKFILE"
    if ! flock -n 200; then
      ${ui.messages.error "Another instance is running."}
      exit 1
    fi

    USER="$1"
    DURATION="$2"
    REASON="$3"
    
    if [ -z "$USER" ]; then
      ${ui.messages.error "Usage: ssh-grant-access USERNAME [DURATION] [REASON]"}
      ${ui.messages.info "Example: ssh-grant-access fr4iser 300 'Emergency access for key setup'"}
      exit 1
    fi

    DURATION=''${DURATION:-300}  # Default to 5 minutes if not provided
    REASON=''${REASON:-"Direct admin grant"}

    ${ui.messages.loading "Granting temporary SSH password authentication for $USER..."}
    ${ui.messages.info "Duration: $DURATION seconds"}
    ${ui.messages.info "Reason: $REASON"}

    # Backup current SSH config
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%s)

    # Enable password authentication
    if ! grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
      sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
      sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
      sudo systemctl restart sshd
      
      if [ $? -eq 0 ]; then
        ${ui.messages.success "SSH password authentication enabled successfully"}
      else
        ${ui.messages.error "Failed to restart SSH service"}
        exit 1
      fi
    else
      ${ui.messages.info "Password authentication already enabled"}
    fi

    ${ui.messages.success "SSH password authentication granted for $USER for $DURATION seconds"}
    ${ui.messages.info "User can now connect using password authentication"}

    # Set up timer to disable access
    (
      sleep $DURATION
      
      # Restore secure SSH config
      sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
      sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
      sudo systemctl restart sshd
      
      ${ui.messages.info "SSH password authentication disabled after $DURATION seconds"}
    ) &
    
    ${ui.messages.info "Auto-disable timer set for $DURATION seconds"}
    ${ui.messages.info "Access will be automatically revoked at: $(date -d \"+$DURATION seconds\")"}
  '';
in {
  options.features.ssh-server-manager.grant-access = {
    enable = mkEnableOption "Direct SSH access grant functionality";
    
    defaultDuration = mkOption {
      type = types.int;
      default = 300;
      description = "Default duration (in seconds) for granted access";
    };

    maxDuration = mkOption {
      type = types.int;
      default = 3600;
      description = "Maximum allowed duration for granted access";
    };
  };

  config = {
    environment.systemPackages = [ grantAccessScript ];

    core.command-center.commands = [
      {
        name = "ssh-grant-access";
        description = "Grant temporary SSH password authentication";
        category = "security";
        script = "${grantAccessScript}/bin/ssh-grant-access";
        arguments = [ "USERNAME" "[DURATION]" "[REASON]" ];
        dependencies = [ "openssh" ];
        shortHelp = "ssh-grant-access USERNAME [DURATION] [REASON] - Grant password auth directly";
        longHelp = ''
          Directly grants temporary SSH password authentication for a specified user.
          This bypasses the request/approval workflow for emergency situations.
          
          Arguments:
            USERNAME  - The username to grant access to
            DURATION  - Duration in seconds (optional, default: 300)
            REASON    - Reason for granting access (optional)
          
          Examples:
            ssh-grant-access fr4iser
            ssh-grant-access fr4iser 600 "Emergency server maintenance"
            ssh-grant-access john 120 "Quick key setup"
        '';
      }
    ];
  };
}
