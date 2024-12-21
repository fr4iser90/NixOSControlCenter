{ config, lib, colors, formatting, reportLevels, currentLevel, systemConfig, ... }:

with lib;

let
  types = import ../../profile-management/types;

  # Get system information
  systemInfo = {
    hasDesktop = systemConfig.desktop != null && systemConfig.desktop != "";
    systemType = systemConfig.systemType;
    desktop = systemConfig.desktop or "none";
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
    ${formatting.section "Profile Configuration"}
    ${formatting.keyValue "System Type" systemInfo.systemType}
    ${formatting.keyValue "Desktop" systemInfo.desktop}
  '';

  # Detailed report adds desktop status and module path
  detailedReport = ''
    ${standardReport}
    ${formatting.keyValue "Has Desktop" (toString systemInfo.hasDesktop)}
    ${formatting.keyValue "Profile Module" (baseNameOf profileModule)}
  '';

in {
  # Minimal level shows nothing
  collect = 
    if currentLevel >= reportLevels.detailed then detailedReport
    else if currentLevel >= reportLevels.standard then standardReport
    else "";
}