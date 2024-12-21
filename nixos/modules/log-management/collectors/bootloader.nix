{ config, lib, pkgs, colors, formatting, reportLevels, currentLevel, ... }:

with lib;

let
  # Determine active bootloader
  bootloader = 
    if config.boot.loader.systemd-boot.enable then "systemd-boot"
    else if config.boot.loader.grub.enable then "grub"
    else if config.boot.loader.refind.enable then "refind"
    else "unknown";

  # Standard report shows basic boot info
  standardReport = ''
    ${formatting.section "Boot Configuration"}
    ${formatting.keyValue "Boot Loader" bootloader}
    ${formatting.keyValue "Kernel" config.boot.kernelPackages.kernel.version}
  '';

  # Detailed report adds bootloader configuration
  detailedReport = ''
    ${standardReport}
    ${optionalString config.boot.loader.systemd-boot.enable ''
      ${formatting.subsection "systemd-boot"}
      ${formatting.keyValue "Editor" (if config.boot.loader.systemd-boot.editor then "enabled" else "disabled")}
      ${formatting.keyValue "Console Mode" config.boot.loader.systemd-boot.consoleMode}
    ''}
  '';

  # Full report adds EFI information
  fullReport = ''
    ${detailedReport}
    ${optionalString config.boot.loader.efi.canTouchEfiVariables ''
      ${formatting.subsection "EFI Configuration"}
      ${formatting.keyValue "System Mount" config.boot.loader.efi.efiSysMountPoint}
    ''}
  '';

in {
  # Minimal level shows nothing
  collect = 
    if currentLevel >= reportLevels.full then fullReport
    else if currentLevel >= reportLevels.detailed then detailedReport
    else if currentLevel >= reportLevels.standard then standardReport
    else "";
}