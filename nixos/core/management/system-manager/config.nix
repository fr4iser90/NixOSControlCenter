{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.core.management.system-manager or {};
  # CRITICAL: Use absolute path to deployed location, not relative (which resolves to store)
  userConfigFile = "/etc/nixos/core/management/system-manager/system-manager-config.nix";
  symlinkPath = "/etc/nixos/configs/system-manager-config.nix";
  configHelpers = import ../module-manager/lib/config-helpers.nix { inherit pkgs lib; backupHelpers = import ../system-manager/lib/backup-helpers.nix { inherit pkgs lib; }; };
  defaultConfig = ''
{
  features = {
    system-logger = true;
    system-checks = true;
    system-config-manager = false;
    system-discovery = false;
    ssh-client-manager = false;
    ssh-server-manager = false;
    bootentry-manager = false;
    homelab-manager = false;
    vm-manager = false;
    ai-workspace = false;
  };
}
'';
in
{
  config = lib.mkMerge [
    # Always import component commands (they'll be conditionally enabled)
    # (import ./components/config-migration/commands.nix)

    # Main config
    (lib.mkIf (cfg.enable or true) {
    system.activationScripts.system-manager-config-symlink =
      configHelpers.setupConfigFile symlinkPath userConfigFile defaultConfig;
    })
  ];
}
