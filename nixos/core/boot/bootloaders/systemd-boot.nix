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
      consoleMode = "auto"; # Can be "auto", "keep", or a specific mode
      memtest86.enable = true;
    };

    # EFI configuration
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot";
    };
  };

  # Enable quiet boot options
  boot.kernelParams = [
    "quiet"                # Reduces kernel messages
    "loglevel=3"           # Limits log messages to critical errors
    "rd.udev.log_priority=3" # Reduces udev messages
    "splash"               # Activates splash screen, if available
  ];
}
