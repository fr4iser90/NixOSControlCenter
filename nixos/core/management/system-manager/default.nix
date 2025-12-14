{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  # Use final config with defaults applied
  cfg = config.systemConfig.management.system-manager or {};

  # Import helpers
  backupHelpers = import ./lib/backup-helpers.nix { inherit pkgs lib; };
  # API definition - always available
  # Pass backupHelpers to configHelpers so it can use it
  configHelpers = import ../module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  apiValue = configHelpers // backupHelpers;

  # moduleConfig kommt automatisch vom module-manager (zentral definiert)
in {
  imports = [
    ./options.nix
    ./commands.nix
    ./config.nix
    # Import all submodules (full-featured modules within system-manager)
    ./submodules/cli-formatter    # CLI formatting submodule
    ./submodules/cli-registry     # CLI command registration submodule
    ./submodules/system-update    # System update submodule
    ./submodules/system-checks    # System validation submodule
    ./submodules/system-logging   # System logging submodule
    # Keep other handlers
    ./handlers/channel-manager.nix
    # NOTE: system-update.nix removed - now in submodules/system-update/
  ];

  config = {
    # moduleConfig kommt automatisch vom module-manager (zentral definiert)

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
