{ config, lib, ui, reportLevels, currentLevel, systemConfig, getModuleConfig, ... }:

with lib;

let
  types = import ../../profile-management/types;

  # Get system information
  systemInfo = {
    hasDesktop = lib.attrByPath ["enable"] false (getModuleConfig "desktop");
    systemType = lib.attrByPath ["systemType"] "desktop" (getModuleConfig "system-manager");
    desktop = lib.attrByPath ["environment"] "none" (getModuleConfig "desktop");
  };

  # Determine profile module path
  profileModule =
    if types.systemTypes.hybrid ? ${systemInfo.systemType} then
      "hybrid/gaming-workstation.nix"
    else if types.systemTypes.desktop ? ${systemInfo.systemType} then
      "desktop/${systemInfo.systemType}.nix"
    else if types.systemTypes.server ? ${systemInfo.systemType} then
      "server/${systemInfo.systemType}.nix"
    else
      throw "Unknown system type: ${systemInfo.systemType}";

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
