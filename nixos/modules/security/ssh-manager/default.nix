{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  on = cfg.enable or false;
  clientOn = cfg.client.enable or false;
  workflowOn = on && (cfg.workflow.enable or false);
  passwordAuth = cfg.passwordAuthentication or true;
  permitRoot = cfg.permitRootLogin or "yes";
in {
  _module.args.cfg = cfg;
  _module.args.sshClientCfg = cfg.client or {};

  imports = [
    ./options.nix
    # Always: wipe legacy systemConfig/.../client-connections.nix (recreated nothing)
    ./client/config.nix
  ] ++ optionals on [
    ./commands.nix
    ./auth.nix
    ./scripts/grant-access.nix
    ./scripts/lockdown.nix
  ] ++ optionals workflowOn [
    ./scripts/request-access.nix
    ./scripts/approve-request.nix
    ./scripts/list-requests.nix
    ./scripts/monitor.nix
  ] ++ optionals clientOn [
    ./client/commands.nix
  ];

  warnings = optional (on && passwordAuth) ''
    ssh-manager: PasswordAuthentication is enabled (bootstrap-safe default).
    After pubkey login works: ncc ssh lockdown
    Temporary reopen later: ncc ssh temp-open / grant-access.
  '';

  services.openssh = mkIf on {
    enable = true;
    settings = {
      PasswordAuthentication = passwordAuth;
      PubkeyAuthentication = true;
      PermitRootLogin = permitRoot;
      KbdInteractiveAuthentication = passwordAuth;
      UsePAM = true;
      LogLevel = "VERBOSE";
      SyslogFacility = "AUTH";
    };
    extraConfig = ''
      ChallengeResponseAuthentication ${if passwordAuth then "yes" else "no"}
      LogLevel VERBOSE
    '';
  };

  security.pam.services.sshd.text = mkIf on ''
    auth required pam_unix.so nullok
    account required pam_unix.so
    password required pam_unix.so nullok sha512
    session required pam_unix.so
  '';

  environment.etc."ssh/banner" = mkIf (on && (cfg.banner or "") != "") {
    text = cfg.banner;
  };

  environment.systemPackages = mkIf clientOn [
    pkgs.fzf
    pkgs.openssh
  ];
}
