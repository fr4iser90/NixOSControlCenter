{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.features.ssh-server-manager.temp-access;
  ui = config.features.terminal-ui.api;

  tempAccessScript = pkgs.writeScriptBin "ssh-temp-access" ''
    #!${pkgs.bash}/bin/bash

    LOCKFILE="/tmp/ssh-temp-access.lock"
    exec 200>$LOCKFILE
    flock -n 200 || { ${ui.messages.error "Another instance is running."}; exit 1; }

    USER="$1"
    DURATION="$2"
    
    if [ -z "$USER" ]; then
      ${ui.messages.error "Usage: ssh-temp-access USERNAME [DURATION]"}
      exit 1
    fi

    DURATION=''${DURATION:-60}  # Default to 60 seconds if not provided

    ${ui.messages.loading "Enabling temporary SSH password authentication for $USER..."}

    # Enable password authentication
    if ! grep -q "^PasswordAuthentication yes" /etc/ssh/sshd_config; then
      sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
      sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication yes/' /etc/ssh/sshd_config
      sudo systemctl restart sshd
    fi

    ${ui.messages.success "SSH password authentication enabled for $USER for $DURATION seconds"}

    # Set up timer to disable access
    (
      sleep $DURATION
      sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
      sudo systemctl restart sshd
      ${ui.messages.info "SSH password authentication disabled after $DURATION seconds"}
    ) &
  '';
in {
  options.features.ssh-server-manager.temp-access = {
    enable = mkEnableOption "Temporary SSH access functionality";
    
    defaultDuration = mkOption {
      type = types.int;
      default = 60;
      description = "Default duration (in seconds) for temporary access";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ tempAccessScript ];

    features.command-center.commands = [
      {
        name = "ssh-temp-access";
        description = "Enable temporary SSH password authentication";
        category = "security";
        script = "${tempAccessScript}/bin/ssh-temp-access";
        arguments = [ "USERNAME" "[DURATION]" ];
        dependencies = [ "openssh" ];
        shortHelp = "ssh-temp-access USERNAME [DURATION] - Enable password auth temporarily";
        longHelp = ''
          Temporarily enables SSH password authentication for a specified user.
          Default duration is 60 seconds unless specified.
        '';
      }
    ];
  };
}
