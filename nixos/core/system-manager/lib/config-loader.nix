# Config loader for systemConfig
# Can be used by both flake.nix (before module evaluation) and system-manager module
{ lib ? null }:

let
  # Helper function to load config if it exists and is valid
  # configsDir must be a path (not a string)
  loadConfig = configName: configsDir:
    let
      # Config file name: ${configName}-config.nix
      configFileName = "${configName}-config.nix";
      
      # Check if configsDir is absolute - if so, skip central /configs/ path in pure mode
      # The central path points to /etc/nixos/configs/ which contains symlinks to /etc
      # In pure mode, we can only access files in the flake source (module paths)
      isAbsolutePath = 
        let
          checkResult = builtins.tryEval (
            let
              configsDirStr = toString configsDir;
            in
              builtins.substring 0 1 configsDirStr == "/"
          );
        in
          if checkResult.success then checkResult.value else true; # Assume absolute if check fails
      
      # Build paths lazily - wrap each path creation in tryEval to handle pure mode
      # This avoids path realization errors when configsDir is absolute
      buildPath = subpath:
        let
          result = builtins.tryEval (configsDir + subpath);
        in
          if result.success then result.value else null;
    
      deployedConfigPath = builtins.tryEval (/etc/nixos/configs/${configFileName});
      
      # Check if deployed config exists and is valid
      isValidConfig = path:
        let
          # Check path existence - this can fail in pure mode for absolute paths
          pathExistsResult = builtins.tryEval (builtins.pathExists path);
          pathExists = if pathExistsResult.success then pathExistsResult.value else false;
          
          # If path exists, try to read and validate it
          checkResult = if !pathExists
            then { success = true; value = false; }
            else builtins.tryEval (
              let
                content = builtins.readFile path;
                trimmed = builtins.replaceStrings [" " "\n" "\t" "\r"] ["" "" "" ""] content;
              in
                builtins.stringLength trimmed >= 2 && builtins.substring 0 1 trimmed == "{"
            );
        in
          if checkResult.success then checkResult.value else false;
      
      # ONLY use deployed config if it exists and is valid
      configPath = if deployedConfigPath.success && isValidConfig deployedConfigPath.value
                   then deployedConfigPath.value
                   else null;
    in
      if configPath != null
      then
        let
          importResult = builtins.tryEval (import configPath);
        in
          if importResult.success then importResult.value else {}
      else {};
  
  # List of optional config files (in merge order)
  optionalConfigs = [
    "desktop"
    "audio"
    "localization"
    "hardware"
    "features"
    "packages"
    "network"
    "security"
    "performance"
    "storage"
    "monitoring"
    "backup"
    "logging"
    "update"
    "services"
    "virtualization"
    "hosting"
    "environment"
    "identity"
    "certificates"
    "compliance"
    "ha"
    "disaster-recovery"
    "secrets"
    "multi-tenant"
    "overrides"
  ];
in
{
  # Load and merge all configs
  # Usage: loadSystemConfig configsDir systemConfigPath
  loadSystemConfig = configsDir: systemConfigPath:
    let
      # Wrap entire function in tryEval to handle pure mode restrictions
      # If configsDir is absolute (like /etc/nixos), path operations will fail in pure mode
      result = builtins.tryEval (
        let
          # 1. Load minimal system-config (MUST exist)
          # If old structure: contains all values, will be overridden by optional configs
          baseConfig = import systemConfigPath;
          
          # 2. Load and merge all optional configs
          # Order is important: later configs override earlier ones
          # Wrap loadConfig in tryEval to handle pure mode restrictions
          safeLoadConfig = configName: 
            let
              configResult = builtins.tryEval (loadConfig configName configsDir);
            in
              if configResult.success then configResult.value else {};
          mergedConfig = baseConfig // builtins.foldl' (acc: configName: acc // safeLoadConfig configName) {} optionalConfigs;
        in
          mergedConfig
      );
    in
      # If loading fails (pure mode with absolute paths), return only base config
      if result.success then result.value else (import systemConfigPath);
  
  # Get list of optional configs (for reference)
  inherit optionalConfigs;
}

