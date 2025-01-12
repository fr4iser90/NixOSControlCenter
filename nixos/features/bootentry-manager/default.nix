{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.features.bootentry-manager;
  
  # Importiere die benötigten Module
  types = import ./lib/types.nix { inherit lib; };
  common = import ./lib/common.nix { inherit lib; };
  
  # Wähle Provider basierend auf dem Bootloader
  providers = {
    grub = import ./providers/grub.nix { inherit config lib pkgs; };
    refind = import ./providers/refind.nix { inherit config lib pkgs; };
    "systemd-boot" = import ./providers/systemd-boot.nix { inherit config lib pkgs; };
  };
  
  selectedProvider = providers.${config.boot.loader.systemd-boot.enable} or providers."systemd-boot";

in {
  options.features.bootentry-manager = {
    enable = mkEnableOption "boot entry manager";
    description = mkOption {
      type = types.str;
      default = "Boot entry management for various bootloaders";
      description = "Feature description";
    };
  };

  config = mkIf cfg.enable {
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