{ config, lib, colors, formatting, reportLevels, currentLevel, ... }:

with lib;

let
  env = import ../../../env.nix;
  types = import ../../profile-management/types;

  systemInfo = {
    hasDesktop = env.desktop != null && env.desktop != "";
    systemType = env.systemType;
    desktop = env.desktop or "none";
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
    if types.systemTypes.hybrid ? ${env.systemType} then
      "hybrid/gaming-workstation.nix"
    else if types.systemTypes.desktop ? ${env.systemType} then
      "desktop/${env.systemType}.nix"
    else if types.systemTypes.server ? ${env.systemType} then
      "server/${env.systemType}.nix"
    else
      throw "Unknown system type: ${env.systemType}";

in {
  collect = 
    if currentLevel >= reportLevels.detailed then detailedReport
    else if currentLevel >= reportLevels.standard then standardReport
    else minimalReport;
}