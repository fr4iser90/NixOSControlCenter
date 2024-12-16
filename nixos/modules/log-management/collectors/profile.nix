{ config, lib, colors, formatting, reportLevels, currentLevel, systemConfig, ... }:

with lib;

let
  types = import ../../profile-management/types;

  systemInfo = {
    hasDesktop = systemConfig.desktop != null && systemConfig.desktop != "";
    systemType = systemConfig.systemType;
    desktop = systemConfig.desktop or "none";
  };

  # Reports für verschiedene Detail-Level
  minimalReport = ''
    echo -e "${colors.magenta}=== Profile Configuration ===${colors.reset}"
    echo -e "System Type: ${systemInfo.systemType}"
  '';

  standardReport = ''
    ${minimalReport}
    echo -e "Desktop: ${systemInfo.desktop}"
  '';

  detailedReport = ''
    ${standardReport}
    echo -e "Has Desktop: ${toString systemInfo.hasDesktop}"
    echo -e "Profile Module: ${baseNameOf profileModule}"
  '';

  profileModule = 
    if types.systemTypes.hybrid ? ${systemConfig.systemType} then
      "hybrid/gaming-workstation.nix"
    else if types.systemTypes.desktop ? ${systemConfig.systemType} then
      "desktop/${systemConfig.systemType}.nix"
    else if types.systemTypes.server ? ${systemConfig.systemType} then
      "server/${systemConfig.systemType}.nix"
    else
      throw "Unknown system type: ${systemConfig.systemType}";

in {
  collect = 
    if currentLevel >= reportLevels.detailed then detailedReport
    else if currentLevel >= reportLevels.standard then standardReport
    else minimalReport;
}