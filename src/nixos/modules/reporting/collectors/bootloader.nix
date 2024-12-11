{ config, lib, pkgs, colors, formatting, reportLevels, currentLevel, ... }:

with lib;

{
  collect = let
    bootloader = 
      if config.boot.loader.systemd-boot.enable then "systemd-boot"
      else if config.boot.loader.grub.enable then "grub"
      else if config.boot.loader.refind.enable then "refind"
      else "unknown";
  in ''
    echo -e "${colors.cyan}=== Boot Configuration ===${colors.reset}"
    echo -e "Boot Loader: ${bootloader}"
    echo -e "Kernel: ${config.boot.kernelPackages.kernel.version}"
    ${if currentLevel >= reportLevels.standard then ''
      echo -e "\nBoot Configuration:"
      ${optionalString config.boot.loader.systemd-boot.enable ''
        echo -e "  systemd-boot:"
        echo -e "    Editor: ${if config.boot.loader.systemd-boot.editor then "enabled" else "disabled"}"
        echo -e "    Console Mode: ${config.boot.loader.systemd-boot.consoleMode}"
      ''}
    '' else ""}
    ${if currentLevel >= reportLevels.detailed then ''
      ${optionalString config.boot.loader.efi.canTouchEfiVariables ''
        echo -e "  EFI:"
        echo -e "    System Mount: ${config.boot.loader.efi.efiSysMountPoint}"
      ''}
    '' else ""}
  '';
}