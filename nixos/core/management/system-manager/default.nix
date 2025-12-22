{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, moduleConfig, ... }:

with lib;

let
  # Use systemConfig from module-manager (_module.args)
  cfg = getModuleConfig "system-manager";

  # Import helpers
  backupHelpers = import ./lib/backup-helpers.nix { inherit pkgs lib; };
  # API definition - always available
  # Pass backupHelpers to configHelpers so it can use it
  configHelpers = import ../module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  apiValue = configHelpers // backupHelpers;

  bootCfg = getModuleConfig "boot";

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
    boot.loader.systemd-boot.enable = bootCfg.bootloader == "systemd-boot";
    boot.loader.grub.enable = bootCfg.bootloader == "grub";
    
    core.management.system-manager.api = apiValue;

    _module.metadata = {
      role = "core";
      name = "system-manager";
      description = "Central system management and configuration";
      category = "management";
      subcategory = "system";
      version = "1.0.0";
    };
  };
}
