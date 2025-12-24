{
  # Boot Entry Manager Configuration
  # This module manages bootloader entries for systemd-boot, GRUB, and rEFInd

  modules = {
    infrastructure = {
      bootentry-manager = {
        enable = false;
        # Boot entry management is automatically enabled when this module is active
        # No additional configuration needed - uses system bootloader configuration
      };
    };
  };
}
