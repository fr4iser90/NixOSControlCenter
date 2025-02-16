{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.features.ssh-server-manager.open-password;
  ui = config.features.terminal-ui.api;
  notifications = config.features.ssh-server-manager.notifications;

  openPasswordScript = pkgs.writeScriptBin "ssh-open-password" ''
    #!${pkgs.bash}/bin/bash

    LOCKFILE="/tmp/ssh-open-password.lock"
    exec 200>$LOCKFILE
    flock -n 200 || { ${ui.messages.error "Another instance is running."}; exit 1; }

    USER="$1"
    REASON="$2"
    
    if [ -z "$USER" ] || [ -z "$REASON" ]; then
      ${ui.messages.error "Usage: ssh-open-password USERNAME REASON"}
      exit 1
    fi

    ${ui.messages.loading "Processing password access request for $USER..."}

    # Send notification to administrators
    ${if notifications.enable then ''
      MESSAGE="Password access requested by $USER\nReason: $REASON"
      
      ${if notifications.types.email.enable then ''
        ${pkgs.mailutils}/bin/mail -s "SSH Password Access Request" ${notifications.types.email.address} <<< "$MESSAGE"
      '' else ""}

      ${if notifications.types.desktop.enable then ''
        ${pkgs.libnotify}/bin/notify-send \
          -u critical \
          "SSH Password Access Request" \
          "$MESSAGE"
      '' else ""}

      ${if notifications.types.webhook.enable then ''
        ${pkgs.curl}/bin/curl -X POST \
          -H 'Content-Type: application/json' \
          -d '{"message": "$MESSAGE"}' \
          ${notifications.types.webhook.url}
      '' else ""}
    '' else ""}
    fi

    ${ui.messages.success "Password access request processed. Administrators have been notified."}
  '';
in {
  options.features.ssh-server-manager.open-password = {
    enable = mkEnableOption "Password access request functionality";
    
    requireReason = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to require a reason for password access requests";
    };
  };

  config = {
    environment.systemPackages = [ openPasswordScript ];

    features.command-center.commands = [
      {
        name = "ssh-open-password";
        description = "Request password-based SSH access";
        category = "security";
        script = "${openPasswordScript}/bin/ssh-open-password";
        arguments = [ "USERNAME" "REASON" ];
        dependencies = [ "mailutils" "libnotify" "curl" ];
        shortHelp = "ssh-open-password USERNAME REASON - Request password access";
        longHelp = ''
          Requests password-based SSH access, notifying administrators.
          Requires a reason for the access request.
        '';
      }
    ];
  };
}
