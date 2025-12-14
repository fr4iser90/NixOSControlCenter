{ config, lib, ui, reportLevels, currentLevel, systemConfig, ... }:

with lib;

let
  types = import ../../profile-management/types;

  # Get system information
  systemInfo = {
    hasDesktop = systemConfig.system.desktop.enable or false;
    systemType = systemConfig.systemType;
    desktop = systemConfig.system.desktop.environment or "none";
  };

  # Determine profile module path
  profileModule = 
    if types.systemTypes.hybrid ? ${systemConfig.systemType} then
      "hybrid/gaming-workstation.nix"
    else if types.systemTypes.desktop ? ${systemConfig.systemType} then
      "desktop/${systemConfig.systemType}.nix"
    else if types.systemTypes.server ? ${systemConfig.systemType} then
      "server/${systemConfig.systemType}.nix"
    else
      throw "Unknown system type: ${systemConfig.systemType}";

  # Standard report shows basic system info
  infoReport = ''
    ${ui.text.header "Profile Configuration"}
    ${ui.tables.keyValue "System Type" systemInfo.systemType}
    ${ui.tables.keyValue "Desktop" systemInfo.desktop}
  '';

  # Detailed report adds desktop status and module path
  debugReport = ''
    ${infoReport}
    ${ui.tables.keyValue "Has Desktop" (toString systemInfo.hasDesktop)}
    ${ui.tables.keyValue "Profile Module" (baseNameOf profileModule)}
  '';

in {
  # Minimal level shows nothing
  collect =
    if currentLevel >= reportLevels.debug then debugReport
    else if currentLevel >= reportLevels.info then infoReport
    else "";
}
