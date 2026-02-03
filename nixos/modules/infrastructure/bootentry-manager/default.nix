{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleMetadata, ... }:

with lib;

let
  
  moduleName = baseNameOf ./. ;        # "bootentry-manager" - automatisch!
  cfg = getModuleConfig moduleName;

  # Importiere die benötigten Module
  common = import ./lib/common.nix { inherit lib; };

  # Wähle Provider basierend auf dem Bootloader
  providers = {
    grub = import ./handlers/grub.nix { inherit config lib pkgs; };
    refind = import ./handlers/refind.nix { inherit config lib pkgs; };
    "systemd-boot" = import ./handlers/systemd-boot.nix { inherit config lib pkgs; };
  };

  selectedProvider = if config.boot.loader.systemd-boot.enable then providers."systemd-boot"
                     else if config.boot.loader.grub.enable then providers.grub
                     else providers."systemd-boot";  # Default fallback

in
{
  imports = [
    (import ./options.nix { inherit lib moduleName; })
  ] ++ optional (cfg.enable or false) ./config.nix;

  # Don't use top-level config = when you have _module!
  # Put config attributes directly at top level
  system.activationScripts = mkIf (cfg.enable or false) {
    bootEntryInit = lib.mkForce selectedProvider.activation.initializeJson;
    bootEntrySync = lib.mkForce selectedProvider.activation.syncEntries;
  };

  environment.systemPackages = mkIf (cfg.enable or false) [
    selectedProvider.scripts.listEntries
    selectedProvider.scripts.renameEntry
    selectedProvider.scripts.resetEntry
  ];
}
