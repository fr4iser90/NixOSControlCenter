# src/nixos/modules/bootloader/lib/entry-management/default.nix
{ config, lib, pkgs }:

let
  core = import ./core.nix { inherit lib; };
  types = import ../types.nix { inherit lib; };
  
  # Provider-Implementierungen
  providers = {
    systemd-boot = import ./providers/systemd-boot.nix {
      inherit config lib pkgs;
      inherit (types) bootEntry entryConfig;
      inherit (core) mkEntryManager;
    };
    
    grub = null;  # TODO: Implementieren
    refind = null;  # TODO: Implementieren
  };

in {
  inherit providers types;
  
  activation = {
    initializeJson = ''
      # Ensure boot entries directory exists
      mkdir -p /boot/loader/entries
      
      # Initialize entry management
      ${providers.systemd-boot.scripts.initJson}
    '';
    
    syncEntries = providers.systemd-boot.activation.syncEntries;
  };
}