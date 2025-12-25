{ lib, getCurrentModuleMetadata, ... }:

let
  metadata = getCurrentModuleMetadata ./.;  # ← Aus Dateipfad ableiten!
  configPath = metadata.configPath;
in {
  options.${configPath} = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;
      description = "Boot module version";
    };
    # Boot module has no user-configurable options - it uses systemConfig.core.base.bootloader
    # to dynamically load the appropriate bootloader implementation
    bootloader = lib.mkOption {
      type = lib.types.enum [ "systemd-boot" "grub" "refind" ];
      default = "systemd-boot";
      description = "Bootloader to use";
    };
  };
}
