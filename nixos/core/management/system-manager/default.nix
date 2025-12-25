{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, moduleConfig, ... }:

with lib;

let
  moduleName = baseNameOf ./. ;        # "system-manager"
  parentName = baseNameOf ../.;        # "management"
  grandparentName = baseNameOf ../../.; # "core"
  configPath = "${grandparentName}.${parentName}.${moduleName}";

  # Cannot use getModuleConfig (chicken-egg problem with core modules)
  cfg = config.${configPath};

  # Import helpers
  backupHelpers = import ./lib/backup-helpers.nix { inherit pkgs lib; };
  # API definition - always available
  apiValue = backupHelpers;

  bootCfg = getModuleConfig "boot";

in {
  imports = [
    ./options.nix
    ./commands.nix
    ./config.nix
    # Import all submodules (full-featured modules within system-manager)
    # NOTE: cli-formatter and cli-registry moved to nixos-control-center
    ./submodules/system-update    # System update submodule
    ./submodules/system-checks    # System validation submodule
    ./submodules/system-logging   # System logging submodule
    # Keep other handlers
    ./handlers/channel-manager.nix
    # NOTE: system-update.nix removed - now in submodules/system-update/
  ];

  config = {
    _module.metadata = {
      role = "core";
      name = moduleName;
      description = "Central system management and configuration";
      category = "management";
      subcategory = "system";
      version = "1.0.0";
    };

    # Modulname einmalig definieren und an Submodule weitergeben
    _module.args.moduleName = moduleName;

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
    
    ${configPath}.api = apiValue;
  };
}
