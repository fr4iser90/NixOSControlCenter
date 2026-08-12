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
  ] ++ optionals on [
    ./commands.nix
    ./auth.nix
    ./scripts/grant-access.nix
    ./scripts/lockdown.nix
  ] ++ optionals workflowOn [
    # Request/approve/monitor workflow — not yet ported cleanly after merge.
    # Keep enable for config compatibility; tools stay off until rewritten.
  ] ++ optionals clientOn [
    ./client/config.nix
    ./client/commands.nix
  ];

  warnings = optional (on && passwordAuth) ''
    ssh-manager: PasswordAuthentication is enabled (bootstrap-safe default).
    After pubkey login works: ncc ssh lockdown
    Temporary reopen later: ncc ssh temp-open / grant-access.
  '' ++ optional workflowOn ''
    ssh-manager: workflow.enable is set, but request/approve/monitor scripts
    are not loaded yet (post-merge cleanup). Use temp-open / grant-access / lockdown.
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
