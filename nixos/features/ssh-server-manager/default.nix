{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = config.features.ssh-server-manager;
  ui = config.features.terminal-ui.api;
  commandCenter = config.features.command-center;
in {
  imports = [
    ./auth.nix
    ./monitoring.nix
    ./notifications.nix
    ./scripts/monitor.nix
    ./scripts/request-access.nix
    ./scripts/approve-request.nix
    ./scripts/list-requests.nix
    ./scripts/grant-access.nix
  ];

  options.features.ssh-server-manager = {
    enable = mkEnableOption "SSH server management features";
    
    banner = mkOption {
      type = types.str;
      default = ''
        ===============================================
        Password authentication is disabled by default.

        If you don't have a public key set up:
        1. Request access: ssh-request-access USERNAME "reason"
        2. Wait for admin approval
        3. Or ask admin to run: ssh-grant-access USERNAME

        For help: ssh-list-requests (admins only)
        ===============================================
      '';
      description = "SSH login banner text";
    };


  };

  config = lib.mkIf cfg.enable {
    # Enable terminal-ui dependency
    features.terminal-ui.enable = true;
    
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

    features.terminal-ui.components.ssh-status = {
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
  };
}
