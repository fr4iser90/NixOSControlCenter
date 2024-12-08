{ config, lib, pkgs, ... }:

let
  env = import ../../env.nix;
  
  # Dynamische Setup-Konfiguration basierend auf Hostname
  currentSetup = {
    name = "${env.hostName}Setup";
    sortKey = "${env.hostName}";
    limit = 10;  # Standard-Limit, könnte auch konfigurierbar sein
  };

  scripts = import ./scripts { 
    inherit pkgs lib env currentSetup; 
  };
in
{
  boot.loader = {
    grub.enable = lib.mkForce false;
    systemd-boot = {
      enable = true;
      configurationLimit = 30;
      editor = false;
      consoleMode = "auto";
      memtest86.enable = true;
    };
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };

  environment.systemPackages = with scripts; [
    renameBootEntries
    listBootEntries
    resetBootEntry
  ];

  system.activationScripts.renameBootEntries = ''
    ${scripts.renameBootEntries}/bin/rename-boot-entries
  '';
}
