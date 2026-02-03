{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./. ;
  cfg = getModuleConfig moduleName;
  # ui = getModuleApi "cli-formatter";  # Removed: not used
  # commandCenter = config.core.management.system-manager.submodules.cli-registry;  # Removed: doesn't exist
in {
  _module.args.cfg = cfg;

  imports = if cfg.enable or false then [
    ./options.nix
    ./commands.nix
    (import ./auth.nix { inherit cfg; })
    (import ./monitoring.nix { inherit cfg; })
    (import ./notifications.nix { inherit cfg; })
    (import ./scripts/monitor.nix { inherit cfg; })
    ./scripts/request-access.nix
    ./scripts/approve-request.nix
    ./scripts/list-requests.nix
    ./scripts/grant-access.nix
  ] else [];

  # Removed: Redundant enable setting (already defined in options.nix)
  
  services.openssh = mkIf (cfg.enable or false) {
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

  security.pam.services.sshd.text = mkIf (cfg.enable or false) ''
    auth required pam_unix.so nullok
    account required pam_unix.so
    password required pam_unix.so nullok sha512
    session required pam_unix.so
  '';

  environment.etc."ssh/banner" = mkIf ((cfg.enable or false) && (cfg.banner or "") != "") {
    text = cfg.banner;
  };

  # Removed: core.management.system-manager option doesn't exist
  # Modules should only set standard NixOS options
}
