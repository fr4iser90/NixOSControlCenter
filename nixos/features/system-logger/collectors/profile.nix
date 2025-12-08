{ config, lib, ui, reportLevels, currentLevel, systemConfig, ... }:

with lib;

let
  types = import ../../profile-management/types;

  # Get system information
  systemInfo = {
    hasDesktop = systemConfig.desktop.enable or false;
    systemType = systemConfig.systemType;
    desktop = systemConfig.desktop.environment or "none";
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
  standardReport = ''
    ${ui.text.header "Profile Configuration"}
    ${ui.tables.keyValue "System Type" systemInfo.systemType}
    ${ui.tables.keyValue "Desktop" systemInfo.desktop}
  '';

  # Detailed report adds desktop status and module path
  detailedReport = ''
    ${standardReport}
    ${ui.tables.keyValue "Has Desktop" (toString systemInfo.hasDesktop)}
    ${ui.tables.keyValue "Profile Module" (baseNameOf profileModule)}
  '';

in {
  # Minimal level shows nothing
  collect = 
    if currentLevel >= reportLevels.detailed then detailedReport
    else if currentLevel >= reportLevels.standard then standardReport
    else "";
}