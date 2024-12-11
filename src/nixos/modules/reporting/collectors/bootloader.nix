{ config, lib, colors, formatting, ... }:

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
  '';
}