{ config, lib, pkgs, colors, formatting, reportLevels, currentLevel, systemConfig, ... }:

with lib;

let
  # Get previous configuration from systemConfig
  prevConfig = systemConfig.previousConfig or {};
  
  # Helper to check if a value has changed
  hasChanged = attr: 
    systemConfig ? ${attr} && 
    prevConfig ? ${attr} && 
    systemConfig.${attr} != prevConfig.${attr};
  
  # Collect all changes
  changes = concatStringsSep "\n" (filter (x: x != null) [
    (optionalString (hasChanged "gpu") 
      (formatting.keyValue "GPU" "${prevConfig.gpu} → ${systemConfig.gpu}"))
    
    (optionalString (hasChanged "cpu")
      (formatting.keyValue "CPU" "${prevConfig.cpu} → ${systemConfig.cpu}"))
    
    (optionalString (hasChanged "users")
      (formatting.keyValue "Users" "${toString (attrNames prevConfig.users)} → ${toString (attrNames systemConfig.users)}"))
  ]);

  # Standard report shows changes if any exist
  standardReport = 
    if changes != "" then ''
      ${formatting.section "Configuration Changes"}
      ${changes}
    '' else "";

in {
  # Show changes for standard level and above, nothing for minimal
  collect = if currentLevel >= reportLevels.standard then standardReport else "";
}