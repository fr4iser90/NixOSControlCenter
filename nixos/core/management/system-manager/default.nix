{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getCurrentModuleMetadata, moduleConfig, ... }:

with lib;

let
  # ALTE getCurrentModuleMetadata verwenden (repariert)
  metadata = getCurrentModuleMetadata ./.;  # ← Jetzt korrekt!
  configPath = metadata.configPath;
  moduleName = metadata.name;  # ← Ableiten aus metadata!

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
    (import ./commands.nix { inherit config lib pkgs systemConfig moduleConfig getModuleConfig getModuleApi; })
    ./config.nix
    # Component Handler (converted from full modules)
    (import ./handlers/system-checks.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; })
    (import ./handlers/system-logging.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi getCurrentModuleMetadata; })
    # Keep other handlers
    ./handlers/channel-manager.nix
    # NOTE: system-update and system-logging handlers kommen später
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

    # moduleName ist nur lokal im let Block - NICHT in _module.args exportieren!
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
