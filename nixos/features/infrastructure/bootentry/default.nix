{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = config.features.infrastructure.bootentry;
  
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
  imports = [
    ./options.nix
    ./config.nix
  ];

  config = mkMerge [
    {
      features.infrastructure.bootentry.enable = mkDefault (systemConfig.features.infrastructure.bootentry or false);
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
    })
  ];
}