{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

with lib;

let
  cfg = getModuleConfig "bootentry-manager";
  
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
    name = "bootentry-manager";
    description = "Boot entry management for multiple bootloaders";
    category = "infrastructure";
    subcategory = "boot";
    stability = "stable";
  };

  imports = if cfg.enable or false then [
    ./options.nix
    ./config.nix
  ] else [];

  config = mkMerge [
    {
      modules.infrastructure.bootentry-manager.enable = mkDefault (cfg.enable or false);
    }
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