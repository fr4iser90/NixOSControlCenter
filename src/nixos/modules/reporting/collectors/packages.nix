{ config, lib, colors, formatting, reportLevels, currentLevel, ... }:

with lib;

let
  # Hilfsfunktionen
  checkPackage = pkg: 
    if isDerivation pkg then {
      name = pkg.name or "unknown";
      exists = true;
      isFree = !(pkg.meta.license.free or false);
      description = pkg.meta.description or "";
      broken = pkg.meta.broken or false;
      version = pkg.version or "unknown";
      license = pkg.meta.license.shortName or "unknown";
    } else {
      name = toString pkg;
      exists = false;
      isFree = true;
      description = "";
      broken = false;
      version = "unknown";
      license = "unknown";
    };

  # Paketanalyse
  packageAnalysis = let
    allPackages = flatten (with config; [
      (environment.systemPackages or [])
      (programs.packages or [])
      (services.packages or [])
    ]);
    checkedPackages = map checkPackage allPackages;
  in {
    total = length checkedPackages;
    packages = checkedPackages;
    free = filter (p: p.isFree) checkedPackages;
    unfree = filter (p: !p.isFree) checkedPackages;
    broken = filter (p: p.broken) checkedPackages;
    invalid = filter (p: !p.exists) checkedPackages;
  };

  # Reports für verschiedene Detail-Level
  minimalReport = ''
    echo -e "${colors.blue}=== Package Analysis ===${colors.reset}"
    echo -e "Total Packages: ${toString packageAnalysis.total}"
    ${optionalString (packageAnalysis.broken != []) ''
      echo -e "${colors.red}Warning: ${toString (length packageAnalysis.broken)} broken packages${colors.reset}"
    ''}
  '';

  standardReport = ''
    ${minimalReport}
    echo -e "${colors.green}Free Packages: ${toString (length packageAnalysis.free)}${colors.reset}"
    echo -e "${colors.yellow}Unfree Packages: ${toString (length packageAnalysis.unfree)}${colors.reset}"
  '';

  detailedReport = ''
    ${standardReport}
    ${optionalString (packageAnalysis.broken != []) ''
      echo -e "\n${colors.red}Broken Packages:${colors.reset}"
      ${formatting.listItems colors.red (map (p: "${p.name}: ${p.description}") packageAnalysis.broken)}
    ''}
    ${optionalString (packageAnalysis.invalid != []) ''
      echo -e "\n${colors.yellow}Invalid Packages:${colors.reset}"
      ${formatting.listItems colors.yellow (map (p: p.name) packageAnalysis.invalid)}
    ''}
  '';

  fullReport = ''
    ${detailedReport}
    echo -e "\n${colors.blue}Package Details:${colors.reset}"
    ${concatMapStrings (p: ''
      echo -e "${colors.cyan}${p.name}:${colors.reset}"
      echo -e "  Version: ${p.version}"
      echo -e "  License: ${p.license}"
      echo -e "  Description: ${p.description}\n"
    '') packageAnalysis.packages}
  '';

in {
  collect = 
    if currentLevel >= reportLevels.full then fullReport
    else if currentLevel >= reportLevels.detailed then detailedReport
    else if currentLevel >= reportLevels.standard then standardReport
    else minimalReport;
}