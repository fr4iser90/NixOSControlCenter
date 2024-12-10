# modules/bootloader/bootloaders/systemd-boot.nix
{ config, lib, pkgs, env, ... }: 

let
  scripts = import ../scripts/systemd-boot {
    inherit pkgs lib env;
    currentSetup = {
      name = "${env.hostName}Setup";
      sortKey = "${env.hostName}";
      limit = env.bootGenerationLimit or 5;
    };
  };
in
{
  # Boot loader configuration
  boot.loader = {
    # Explicitly disable GRUB as we're using systemd-boot
    grub.enable = lib.mkForce false;

    # systemd-boot configuration
    systemd-boot = {
      enable = true;                  # Use systemd-boot as the main bootloader
      configurationLimit = 15;        # Maximum total boot entries to keep
      editor = false;                 # Disable boot parameter editing for security
      consoleMode = "auto";          # Automatically detect best console resolution
      memtest86.enable = true;       # Include memory testing utility in boot menu
    };

    # EFI boot configuration
    efi = {
      canTouchEfiVariables = true;   # Allow system to modify EFI boot entries
      efiSysMountPoint = "/boot";    # Mount point for the EFI system partition
    };
  };


  # Run boot entry renaming script after system activation
  # Only executes if systemd-boot is enabled
  system.activationScripts.renameBootEntries = lib.mkIf (config.boot.loader.systemd-boot.enable) ''
    ${scripts.renameBootEntries}/bin/rename-boot-entries
  '';
}