{ config, lib, pkgs, colors, formatting, reportLevels, currentLevel, systemConfig, ... }:

let
  formatSection = formatting.formatSection;
  formatList = formatting.formatList;
  
  # Hole die vorherige Konfiguration aus dem systemConfig
  prevConfig = systemConfig.previousConfig or {};
  
  # Funktion zum Vergleichen von Werten
  hasChanged = attr: 
    systemConfig ? ${attr} && 
    prevConfig ? ${attr} && 
    systemConfig.${attr} != prevConfig.${attr};
  
  # Sammle alle Änderungen
  changes = lib.concatStringsSep "\n" (lib.filter (x: x != null) [
    (lib.optionalString (hasChanged "gpu") 
      "  GPU: ${prevConfig.gpu} → ${systemConfig.gpu}")
    
    (lib.optionalString (hasChanged "cpu")
      "  CPU: ${prevConfig.cpu} → ${systemConfig.cpu}")
    
    (lib.optionalString (hasChanged "users")
      "  Users: ${toString (builtins.attrNames prevConfig.users)} → ${toString (builtins.attrNames systemConfig.users)}")
  ]);

  collectChanges = if changes != "" then ''
    echo -e "\n''${colors.blue}=== Configuration Changes ===${colors.reset}"
    echo -e "${changes}"
  '' else "";

in {
  collect = collectChanges;
}