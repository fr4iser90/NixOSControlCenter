{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

with lib;

let
  # Single Source: Modulname nur einmal definieren
  moduleName = "ssh-server-manager";
  cfg = getModuleConfig moduleName;
  ui = getModuleApi "cli-formatter";
  commandCenter = config.core.management.system-manager.submodules.cli-registry;
in {
  _module.metadata = {
    role = "optional";
    name = moduleName;
    description = "SSH server access management and monitoring";
    category = "security";
    subcategory = "ssh";
    version = "1.0.0";
  };

  # Modulname einmalig definieren und an Submodule weitergeben
  _module.args.moduleName = moduleName;

  imports = if cfg.enable or false then [
    ./options.nix
    (import ./auth.nix { inherit cfg; })
    (import ./monitoring.nix { inherit cfg; })
    (import ./notifications.nix { inherit cfg; })
    (import ./scripts/monitor.nix { inherit cfg; })
    ./scripts/request-access.nix
    ./scripts/approve-request.nix
    ./scripts/list-requests.nix
    ./scripts/grant-access.nix
  ] else [];

  # Provide cfg to all submodules
  _module.args.cfg = cfg;

  config = mkMerge [
    {
      modules.security.ssh-server-manager.enable = mkDefault (cfg.enable or false);
    }
    (mkIf cfg.enable {
    # Enable terminal-ui dependency
    # modules.terminal-ui.enable removed (cli-formatter is Core) = true;
    
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

    core.management.system-manager.submodules.cli-formatter.components.ssh-status = {
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
