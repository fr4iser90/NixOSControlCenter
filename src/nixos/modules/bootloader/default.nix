# modules/bootloader/default.nix
{ config, lib, pkgs, ... }:

let
  env = import ../../env.nix;
  
  # Bootloader configurations
  bootloaders = {
    systemd-boot = {
      module = ./bootloaders/systemd-boot.nix;
      scripts = ./scripts/systemd-boot;
    };
    grub = {
      module = ./bootloaders/grub.nix;
      scripts = ./scripts/grub;
    };
    refind = {
      module = ./bootloaders/refind.nix;
      scripts = ./scripts/refind;
    };
  };

  # Select bootloader configuration
  selectedLoader = bootloaders.${env.bootloader} or bootloaders.systemd-boot;
  bootloaderConfig = import selectedLoader.module {
    inherit config lib pkgs env;
  };

  # Bootloader-specific scripts
  scripts = if builtins.pathExists selectedLoader.scripts
           then import selectedLoader.scripts {
             inherit pkgs lib env;
             currentSetup = {
               name = "${env.hostName}Setup";
               sortKey = "${env.hostName}";
               limit = env.bootGenerationLimit or 5;
             };
           }
           else {};

in {
  imports = [ bootloaderConfig ];

  # Common boot configuration
  boot = {
    initrd = {
      compressor = "zstd";
      compressorArgs = [ "-19" "-T0" ];
      systemd.enable = true;
      includeDefaultModules = true;
    };
  };

  # Make bootloader-specific utilities available if they exist
  environment.systemPackages = lib.optionals (scripts != {}) (with scripts; [
    renameBootEntries
    listBootEntries
    resetBootEntry
  ]);

  assertions = [
    {
      assertion = builtins.hasAttr env.bootloader bootloaders;
      message = "Invalid bootloader selection: ${env.bootloader}";
    }
  ];
}