{ config, lib, pkgs, ... }: 

{
  # Explicitly disable systemd-boot
  systemd-boot.enable = lib.mkForce false;
  
  # Boot loader configuration
  boot.loader = {
    # Enable GRUB as the bootloader
    grub = {
      enable = true;
      efiSupport = true;
      copyKernels = true;

      # Silent boot configuration
      extraConfig = ''
        GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 rd.udev.log_priority=3 splash"
        GRUB_TERMINAL_OUTPUT="console"  # Verhindert grafische Ausgabe von GRUB selbst
        GRUB_TIMEOUT_STYLE=hidden      # Versteckt das Menü (bei Boot-Problemen kann man ESC drücken)
        GRUB_TIMEOUT=0                 # Setzt die Boot-Verzögerung auf 0 Sekunden
      '';

      device = "nodev"; # Verhindert automatisches Installieren auf einem Laufwerk, da EFI verwendet wird
    };

    # EFI configuration
    efi = {
      canTouchEfiVariables = true;
      efiSysMountPoint = "/boot/efi";
    };
  };
}
