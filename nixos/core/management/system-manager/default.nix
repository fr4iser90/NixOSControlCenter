{ config, lib, pkgs, ... }:

with lib;

let
  # USE config from Config Manager module
  cfg = config.systemConfigManager.systemConfig;

  # Import helpers
  backupHelpers = import ./lib/backup-helpers.nix { inherit pkgs lib; };
  # API definition - always available
  # Pass backupHelpers to configHelpers so it can use it
  configHelpers = import ../module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  apiValue = configHelpers // backupHelpers;
in {
  imports = [
    ./options.nix
    ./commands.nix
    ./config.nix
    # Import all submodules (full-featured modules within system-manager)
    ./submodules/cli-formatter    # CLI formatting submodule
    ./submodules/cli-registry     # CLI command registration submodule
    ./submodules/system-update    # System update submodule - DISABLED: needs moduleConfig
    ./submodules/system-checks    # System validation submodule - DISABLED: recursion issue
    ./submodules/system-logging   # System logging submodule - DISABLED: recursion issue
    # Keep other handlers
    ./handlers/channel-manager.nix
    # NOTE: system-update.nix removed - now in submodules/system-update/
  ];

  config = {
    # System-Manager ist Core - immer geladen
    # Version-Info und Deprecation-Warnungen sind immer verfügbar
    # Updates sind optional (enableUpdates = false by default)

    # USE loaded config values
    users.users = lib.mapAttrs (name: userCfg: {
      isNormalUser = true;
      extraGroups = [ "wheel" "networkmanager" ];
      shell = pkgs.${userCfg.defaultShell or "bash"};
    }) (cfg.users or {});

    # Bootloader from loaded config
    boot.loader.systemd-boot.enable = cfg.system.bootloader == "systemd-boot";
    boot.loader.grub.enable = cfg.system.bootloader == "grub";
    
    core.management.system-manager.api = apiValue;
  };
}
