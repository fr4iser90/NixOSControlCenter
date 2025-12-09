{ config, lib, pkgs, ui, reportLevels, currentLevel, ... }:

with lib;

let
  # Determine active bootloader
  bootloader = 
    if config.boot.loader.systemd-boot.enable then "systemd-boot"
    else if config.boot.loader.grub.enable then "grub"
    else if config.boot.loader.refind.enable then "refind"
    else "unknown";

  # Standard report shows basic boot info
  infoReport = ''
    ${ui.text.header "Boot Configuration"}
    ${ui.tables.keyValue "Boot Loader" bootloader}
    ${ui.tables.keyValue "Kernel" config.boot.kernelPackages.kernel.version}
  '';

  # Detailed report adds bootloader configuration
  debugReport = ''
    ${infoReport}
    ${optionalString config.boot.loader.systemd-boot.enable ''
      ${ui.text.subHeader "systemd-boot"}
      ${ui.tables.keyValue "Editor" (if config.boot.loader.systemd-boot.editor then "enabled" else "disabled")}
      ${ui.tables.keyValue "Console Mode" config.boot.loader.systemd-boot.consoleMode}
    ''}
  '';

  # Full report adds EFI information
  traceReport = ''
    ${debugReport}
    ${optionalString config.boot.loader.efi.canTouchEfiVariables ''
      ${ui.text.subHeader "EFI Configuration"}
      ${ui.tables.keyValue "System Mount" config.boot.loader.efi.efiSysMountPoint}
    ''}
  '';

in {
  # Minimal level shows nothing
  collect = 
    if currentLevel >= reportLevels.full then traceReport
    else if currentLevel >= reportLevels.detailed then debugReport
    else if currentLevel >= reportLevels.standard then infoReport
    else "";
}