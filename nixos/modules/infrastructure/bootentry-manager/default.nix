{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleMetadata, ... }:

with lib;

let
  # Single Source: Modulname nur einmal definieren
  moduleName = "bootentry-manager";
  cfg = getModuleConfig moduleName;

  # Importiere die benötigten Module
  common = import ./lib/common.nix { inherit lib; };

  # Wähle Provider basierend auf dem Bootloader
  providers = {
    grub = import ./providers/grub.nix { inherit config lib pkgs; };
    refind = import ./providers/refind.nix { inherit config lib pkgs; };
    "systemd-boot" = import ./providers/systemd-boot.nix { inherit config lib pkgs; };
  };

  selectedProvider = if config.boot.loader.systemd-boot.enable then providers."systemd-boot"
                     else if config.boot.loader.grub.enable then providers.grub
                     else providers."systemd-boot";  # Default fallback

in {
  _module.metadata = {
    role = "optional";
    name = moduleName;
    description = "Boot entry management for multiple bootloaders";
    category = "infrastructure";
    subcategory = "boot";
    stability = "experimental";
    version = "1.0.0";
  };

  imports = if cfg.enable or true then [
    (import ./options.nix { inherit moduleName; })
    ./config.nix
  ] else [];

  # Modulname einmalig definieren und an Submodule weitergeben
  _module.args.moduleName = moduleName;

  config = mkMerge [
    (let
      # Generisch: enable-Flag aus Discovery-Pfad setzen
      moduleMeta = getModuleMetadata moduleName;
      enablePath = lib.splitString "." moduleMeta.enablePath;
    in
      lib.setAttrByPath enablePath (mkDefault (cfg.enable or true))
    )
    (mkIf cfg.enable {
    # Activation scripts
    config.system.activationScripts = {
      bootEntryInit = lib.mkForce selectedProvider.activation.initializeJson;
      bootEntrySync = lib.mkForce selectedProvider.activation.syncEntries;
    };

    # Management tools
    environment.systemPackages = [
      selectedProvider.scripts.listEntries
      selectedProvider.scripts.renameEntry
      selectedProvider.scripts.resetEntry
    ];
    })
  ];
}