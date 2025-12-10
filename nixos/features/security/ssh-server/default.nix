{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = systemConfig.features.security.ssh-server;
  ui = config.core.cli-formatter.api;
  commandCenter = config.core.command-center;
in {
  imports = [
    ./options.nix
    ./auth.nix
    ./monitoring.nix
    ./notifications.nix
    ./scripts/monitor.nix
    ./scripts/request-access.nix
    ./scripts/approve-request.nix
    ./scripts/list-requests.nix
    ./scripts/grant-access.nix
  ];

  config = mkMerge [
    {
      features.security.ssh-server.enable = mkDefault (systemConfig.features.security.ssh-server or false);
    }
    (mkIf cfg.enable {
    # Enable terminal-ui dependency
    # features.terminal-ui.enable removed (cli-formatter is Core) = true;
    
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PubkeyAuthentication = true;
        PermitRootLogin = "no";
        KbdInteractiveAuthentication = false;
        UsePAM = true;
        LogLevel = "VERBOSE";
        SyslogFacility = "AUTH";
      };
      extraConfig = ''
        ChallengeResponseAuthentication yes
        LogLevel VERBOSE
      '';
    };

    security.pam.services.sshd.text = ''
      auth required pam_unix.so nullok
      account required pam_unix.so
      password required pam_unix.so nullok sha512
      session required pam_unix.so
    '';

    environment.etc."ssh/banner".text = cfg.banner;

    core.cli-formatter.components.ssh-status = {
      enable = true;
      refreshInterval = 5;
      template = ''
        ${ui.text.header "SSH Status"}
        ${ui.tables.keyValue "Password Auth" (if config.services.openssh.settings.PasswordAuthentication then "Enabled" else "Disabled")}
        ${ui.tables.keyValue "Active Sessions" "$(ss -tn state established '( dport = :ssh )' | wc -l)"}
        ${ui.tables.keyValue "Client Alive Interval" "${toString config.services.openssh.settings.ClientAliveInterval}"}
        ${ui.tables.keyValue "Client Alive Count Max" "${toString config.services.openssh.settings.ClientAliveCountMax}"}
      '';
    };
    })
  ];
}
