{ config, lib, pkgs, ... }:

with lib;

let
  env = import ../../env.nix;
  types = import ./types;
  
  # ANSI Farben
  colors = {
    red = "\\033[0;31m";
    green = "\\033[0;32m";
    yellow = "\\033[0;33m";
    blue = "\\033[0;34m";
    reset = "\\033[0m";
  };

  # Hilfsfunktionen
  checkPackage = pkg: 
    if isDerivation pkg then {
      name = pkg.name or "unknown";
      exists = true;
      isFree = !(pkg.meta.license.free or false);
      description = pkg.meta.description or "";
      broken = pkg.meta.broken or false;
    } else {
      name = toString pkg;
      exists = false;
      isFree = true;
      description = "";
      broken = false;
    };

  # Systemanalyse
  systemInfo = {
    hasDesktop = env.desktop != null && env.desktop != "";
    systemType = env.systemType;
    desktop = env.desktop or "none";
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

  # Report generieren
  makeReport = analysis: ''
    echo -e "${colors.blue}=== NixOS System Report ===${colors.reset}"
    echo -e "System Type: ${systemInfo.systemType}"
    echo -e "Desktop: ${systemInfo.desktop}"
    echo
    echo -e "${colors.blue}=== Package Analysis ===${colors.reset}"
    echo -e "Total Packages: ${toString analysis.total}"
    echo -e "${colors.green}Free Packages: ${toString (length analysis.free)}${colors.reset}"
    echo -e "${colors.yellow}Unfree Packages: ${toString (length analysis.unfree)}${colors.reset}"
    
    ${optionalString (analysis.broken != []) ''
      echo -e "\n${colors.red}!!! Broken Packages !!!${colors.reset}"
      ${concatMapStrings (p: ''echo -e "${colors.red}  - ${p.name}: ${p.description}${colors.reset}"'') analysis.broken}
    ''}
    
    ${optionalString (analysis.invalid != []) ''
      echo -e "\n${colors.yellow}Invalid Packages:${colors.reset}"
      ${concatMapStrings (p: ''echo -e "${colors.yellow}  - ${p.name}${colors.reset}"'') analysis.invalid}
    ''}
  '';

  profileModule = 
    if types.systemTypes.hybrid ? ${env.systemType} then
      ./hybrid/gaming-workstation.nix
    else if types.systemTypes.desktop ? ${env.systemType} then
      ./desktop/${env.systemType}.nix
    else if types.systemTypes.server ? ${env.systemType} then
      ./server/${env.systemType}.nix
    else
      throw "Unknown system type: ${env.systemType}";

in {
  imports = [
    profileModule
  ] ++ (optionals systemInfo.hasDesktop [
    ../desktop 
    ../sound/index.nix
  ]);

  system.activationScripts.systemReport = {
    deps = [];
    text = makeReport packageAnalysis;
  };
}