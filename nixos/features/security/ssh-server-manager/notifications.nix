{ config, lib, pkgs, ... }:

with lib;

let
  cfg = systemConfig.features.security.ssh-server.notifications;
  ui = config.core.cli-formatter.api;

  notificationTypes = {
    email = {
      enable = mkEnableOption "Email notifications";
      address = mkOption {
        type = types.str;
        default = "admin@example.com";
        description = "Email address to send notifications to";
      };
    };

    desktop = {
      enable = mkEnableOption "Desktop notifications";
      urgency = mkOption {
        type = types.enum ["low" "normal" "critical"];
        default = "normal";
        description = "Urgency level for desktop notifications";
      };
    };

    webhook = {
      enable = mkEnableOption "Webhook notifications";
      url = mkOption {
        type = types.str;
        default = "https://example.com/webhook";
        description = "Webhook URL for notifications";
      };
    };
  };

  sendNotification = level: message: ''
    ${if cfg.types.email.enable then ''
      ${pkgs.mailutils}/bin/mail -s "SSH Notification (${level})" ${cfg.types.email.address} <<< "${message}"
    '' else ""}
    
    ${if cfg.types.desktop.enable then ''
      ${pkgs.libnotify}/bin/notify-send \
        -u ${cfg.types.desktop.urgency} \
        "SSH Notification (${level})" \
        "${message}"
    '' else ""}
    
    ${if cfg.types.webhook.enable then ''
      ${pkgs.curl}/bin/curl -X POST \
        -H 'Content-Type: application/json' \
        -d '{"level": "${level}", "message": "${message}"}' \
        ${cfg.types.webhook.url}
    '' else ""}
  '';
in {
  options.features.security.ssh-server.notifications = {
    enable = mkEnableOption "SSH notification system";
    
    types = mkOption {
      type = types.submodule notificationTypes;
      default = {};
      description = "Configuration for different notification types";
    };

    notificationLevel = mkOption {
      type = types.enum ["none" "basic" "detailed"];
      default = "detailed";
      description = "Level of detail for notifications";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      mailutils
      libnotify
      curl
    ];

    core.command-center.commands = [
      {
        name = "ssh-notify-test";
        description = "Test SSH notification system";
        category = "monitoring";
        script = ''
          ${sendNotification "test" "This is a test notification from the SSH manager"}
          ${ui.messages.success "Test notification sent"}
        '';
        dependencies = [ "mailutils" "libnotify" "curl" ];
        shortHelp = "ssh-notify-test - Test notification system";
        longHelp = ''
          Sends a test notification through all enabled notification channels.
          Useful for verifying notification configuration.
        '';
      }
    ];
  };
}
