{
  # Boot System Configuration
  # This is a core module that dynamically loads bootloader implementations
  # No user configuration needed - bootloader is selected via systemConfig.system.bootloader

  boot = {
    # Bootloader selection is handled centrally in system-config.nix
    # Available options: "systemd-boot", "grub", "refind"
  };
}
