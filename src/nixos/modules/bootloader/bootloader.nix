{ config, lib, pkgs, ... }:

let
  env = import ../../env.nix;
  scripts = import ./scripts { inherit pkgs lib env; };
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
