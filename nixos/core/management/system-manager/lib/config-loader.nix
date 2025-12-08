# Config loader for systemConfig
# Can be used by both flake.nix (before module evaluation) and system-manager module
{ lib ? null }:

let
  # Helper function to load config if it exists and is valid
  # configsDir must be a path (not a string)
  # Loads directly from module user-configs/ (real files), not from /configs/ (symlinks)
  loadConfig = configName: configsDir:
    let
      configFileName = "${configName}-config.nix";
      
      # Search paths in order of priority - load directly from module user-configs/
      # Special cases: features-config.nix is in system-manager, packages-config.nix is in packages/
      modulePaths = [
        # Standard: Modul-Name = Config-Name (z.B. hardware-config.nix in hardware/)
        (configsDir + "/core/${configName}/user-configs/${configFileName}")
        # Features can also be in features/ modules
        (configsDir + "/features/${configName}/user-configs/${configFileName}")
        # Sonderfall: features-config.nix liegt in system-manager
        (configsDir + "/core/system-manager/user-configs/${configFileName}")
        # Sonderfall: packages-config.nix liegt in packages/
        (configsDir + "/packages/user-configs/${configFileName}")
      ];
      
      # Check if config file is valid (not empty, starts with '{')
      isValidConfig = path:
        let
          pathExistsResult = builtins.tryEval (builtins.pathExists path);
          pathExists = if pathExistsResult.success then pathExistsResult.value else false;
        in
          if !pathExists
          then false
          else
            let
              contentResult = builtins.tryEval (builtins.readFile path);
              content = if contentResult.success then contentResult.value else "";
              trimmed = builtins.replaceStrings [" " "\n" "\t" "\r"] ["" "" "" ""] content;
            in
              builtins.stringLength trimmed >= 2 && builtins.substring 0 1 trimmed == "{";
      
      # Find first existing and valid config file
      validPaths = builtins.filter isValidConfig modulePaths;
      configPath = if builtins.length validPaths > 0 then builtins.head validPaths else null;
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
      # 1. Load minimal system-config (MUST exist)
      baseConfig = import systemConfigPath;
      
      # 2. Load and merge all optional configs
      # Order is important: later configs override earlier ones
      mergedConfig = baseConfig // builtins.foldl' (acc: configName: acc // loadConfig configName configsDir) {} optionalConfigs;
    in
      mergedConfig;
  
  # Get list of optional configs (for reference)
  inherit optionalConfigs;
}

