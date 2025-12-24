{ config, lib, pkgs, cfg, corePathsLib, ... }:

with lib;

let
  # notificationsCfg.notifications is passed from parent module
  notificationsCfg = notificationsCfg.notifications or {};
  ui = getModuleApi "cli-formatter";

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
    ${if notificationsCfg.types.email.enable then ''
      ${pkgs.mailutils}/bin/mail -s "SSH Notification (${level})" ${notificationsCfg.types.email.address} <<< "${message}"
    '' else ""}
    
    ${if notificationsCfg.types.desktop.enable then ''
      ${pkgs.libnotify}/bin/notify-send \
        -u ${notificationsCfg.types.desktop.urgency} \
        "SSH Notification (${level})" \
        "${message}"
    '' else ""}
    
    ${if notificationsCfg.types.webhook.enable then ''
      ${pkgs.curl}/bin/curl -X POST \
        -H 'Content-Type: application/json' \
        -d '{"level": "${level}", "message": "${message}"}' \
        ${notificationsCfg.types.webhook.url}
    '' else ""}
  '';
in {
  options.modules.security.ssh-server.notifications = {
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

  config = mkIf notificationsCfg.enable {
    environment.systemPackages = with pkgs; [
      mailutils
      libnotify
      curl
    ];

    config = lib.mkMerge [
      (lib.setAttrByPath corePathsLib.getCliRegistryCommandsPathList [
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
      ])
    ];
  };
}
