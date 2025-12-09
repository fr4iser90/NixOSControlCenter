{
  # Boot Entry Manager Configuration
  # This feature manages bootloader entries for systemd-boot, GRUB, and rEFInd

  features = {
    infrastructure = {
      bootentry = {
        enable = false;
        # Boot entry management is automatically enabled when this feature is active
        # No additional configuration needed - uses system bootloader configuration
      };
    };
  };
}
