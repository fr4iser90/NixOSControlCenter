{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = config.features.bootentry-manager;
  
  # Importiere die benötigten Module
  common = import ./lib/common.nix { inherit lib; };
  
  # Wähle Provider basierend auf dem Bootloader
  providers = {
    grub = import ./providers/grub.nix { inherit config lib pkgs; };
    refind = import ./providers/refind.nix { inherit config lib pkgs; };
    "systemd-boot" = import ./providers/systemd-boot.nix { inherit config lib pkgs; };
  };
  
  selectedProvider = providers.${config.boot.loader.systemd-boot.enable} or providers."systemd-boot";

in {
  imports = [
    ./options.nix
  ];

  config = mkMerge [
    {
      features.bootentry-manager.enable = mkDefault (systemConfig.features.bootentry-manager or false);
    }
    (mkIf cfg.enable {
    # Activation scripts
    system.activationScripts = {
      bootEntryInit = lib.mkForce selectedProvider.activation.initializeJson;
      bootEntrySync = lib.mkForce selectedProvider.activation.syncEntries;
    };

    # Management tools
    environment.systemPackages = [
      selectedProvider.scripts.listEntries
      selectedProvider.scripts.renameEntry
      selectedProvider.scripts.resetEntry
    ];
  };
}