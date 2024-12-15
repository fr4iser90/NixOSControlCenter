{ config, lib, pkgs, systemConfig, ... }: 

let
  entryManager = import ../lib/entry-management/providers/systemd-boot.nix {
    inherit config lib pkgs;
  };
in
{
  # Boot loader configuration
  boot.loader = {
    # Explicitly disable GRUB
    grub.enable = lib.mkForce false;

    # systemd-boot configuration
    systemd-boot = {
      enable = true;
      configurationLimit = 15;
      editor = false;
      consoleMode = "auto";
      memtest86.enable = true;
    };

    # EFI configuration
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };

  # Activation hooks for entry management
  system.activationScripts = lib.optionalAttrs systemConfig.entryManagement {
    # Initialize JSON storage
    bootEntryInit = lib.mkForce entryManager.activation.initializeJson;
    
    # Sync boot entries
    bootEntrySync = lib.mkIf config.boot.loader.systemd-boot.enable 
      (lib.mkForce entryManager.activation.syncEntries);
  };

  # Make management utilities available if entry management is enabled
  environment.systemPackages = lib.optionals systemConfig.entryManagement [
    entryManager.scripts.listEntries
    entryManager.scripts.renameEntry
    entryManager.scripts.resetEntry
  ];
}