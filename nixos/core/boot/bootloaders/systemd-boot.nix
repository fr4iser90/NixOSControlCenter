{ config, lib, pkgs, ... }: 

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
}