# Config loader for systemConfig
# Can be used by both flake.nix (before module evaluation) and system-manager module
# GENERIC: Dynamically discovers all config files and their domain structure
{ lib ? null }:

let
  # Fallback lib functions if lib is not provided
  filterAttrs = if lib != null then lib.filterAttrs else (f: set: 
    builtins.listToAttrs (builtins.filter (x: f x.name x.value) (builtins.attrValues (builtins.mapAttrs (n: v: { name = n; value = v; }) set))));
  
  hasSuffix = if lib != null then lib.hasSuffix else (suffix: str:
    let
      strLen = builtins.stringLength str;
      suffixLen = builtins.stringLength suffix;
    in
      strLen >= suffixLen && 
      builtins.substring (strLen - suffixLen) suffixLen str == suffix);
  
  reverseList = if lib != null then lib.reverseList else (xs: 
    let
      len = builtins.length xs;
      indices = builtins.genList (i: len - i - 1) len;
    in
      map (i: builtins.elemAt xs i) indices);
  
  recursiveUpdate = if lib != null then lib.recursiveUpdate else (x: y:
    if builtins.isAttrs x && builtins.isAttrs y
    then x // (builtins.mapAttrs (name: value: 
      if builtins.hasAttr name x && builtins.isAttrs (x.${name}) && builtins.isAttrs value
      then recursiveUpdate x.${name} value
      else value
    ) y)
    else y);
  
  # Helper: Safely read directory, return empty set on error
  safeReadDir = path:
    let result = builtins.tryEval (builtins.readDir path);
    in if result.success then result.value else {};
  
  # Helper: Safely check if path exists
  safePathExists = path:
    let result = builtins.tryEval (builtins.pathExists path);
    in if result.success then result.value else false;
  
  # Helper: Safely read file, return empty string on error
  safeReadFile = path:
    let result = builtins.tryEval (builtins.readFile path);
    in if result.success then result.value else "";
  
  # Helper: Safely import file, return empty set on error
  safeImport = path:
    let result = builtins.tryEval (import path);
    in if result.success then result.value else {};
  
  # Extract domain path from file path
  # Example: core/system/audio/audio-config.nix → ["system" "audio"]
  # Example: features/infrastructure/vm/vm-config.nix → ["infrastructure" "vm"]
  extractDomainPath = configsDir: configPath:
    let
      pathStr = toString configPath;
      dirStr = toString configsDir;
      # Get relative path by removing configsDir prefix
      relativePath = if builtins.stringLength pathStr > builtins.stringLength dirStr
        then builtins.substring (builtins.stringLength dirStr + 1) 
             (builtins.stringLength pathStr - builtins.stringLength dirStr - 1) 
             pathStr
        else "";
      
      # Split path into components
      splitPath = builtins.split "/" relativePath;
      
      # Extract string components (filter out nulls from split)
      pathComponents = builtins.filter (p: builtins.isString p && p != "") 
        (map (s: if builtins.isString s then s else null) splitPath);
      
      # Filter out config file name (no more user-configs/ directory)
      relevantParts = builtins.filter (p:
        !hasSuffix "-config.nix" p
      ) pathComponents;
    in
      # Pattern: <top-level>/<domain>/.../<module>/<config>
      # Result: [<domain>, ..., <module>] (skip top-level)
      # Special case: Configs in /etc/nixos/configs/ merge at top level
      if builtins.length relevantParts == 1 && builtins.head relevantParts == "configs"
      then []  # Configs in /etc/nixos/configs/ → merge at top level
      else if builtins.length relevantParts >= 2
      then builtins.tail relevantParts  # Remove top-level, keep domain(s) + module
      else if builtins.length relevantParts == 1
      then relevantParts  # Just module name, no domain (legacy)
      else [];
  
  # Check if config file is valid (exists, not empty, starts with '{')
  isValidConfig = path:
    safePathExists path && (
      let
        content = safeReadFile path;
        trimmed = builtins.replaceStrings [" " "\n" "\t" "\r"] ["" "" "" ""] content;
      in
        builtins.stringLength trimmed >= 2 && builtins.substring 0 1 trimmed == "{"
    );
  
  # Recursively discover all paths to a specific config file
  # Pattern: <top-level>/<domain>/.../<module>/<config-name>-config.nix
  discoverConfigPaths = configName: configsDir: topLevel: currentPath: depth:
    let
      configFileName = "${configName}-config.nix";
      currentDir = configsDir + "/${currentPath}";
      dir = safeReadDir currentDir;
      subDirs = builtins.attrNames (filterAttrs (name: type: type == "directory") dir);
      
      # Try direct module path
      directPath = currentDir + "/${configName}/${configFileName}";
      
      # Recursively search subdirectories (limit depth to prevent infinite recursion)
      subPaths = if depth < 5 then
        builtins.concatMap (subDir: 
          discoverConfigPaths configName configsDir topLevel "${currentPath}/${subDir}" (depth + 1)
        ) subDirs
      else [];
    in
      [ directPath ] ++ subPaths;
  
  # Load a single config file
  # Returns: { value = <config-value>; path = <found-path>; domainPath = [<domain>, ...]; } or null
  loadConfig = configName: configsDir: configsPath:
    let
      # Use configurable configsPath instead of hardcoded /etc/nixos/configs
      configPath = configsPath + "/" + configName + "-config.nix";
    in
      if builtins.pathExists configPath && isValidConfig configPath then
        let
          loadedConfig = safeImport configPath;
          # Take the whole loaded config file
          configValue = loadedConfig;
          domainPath = extractDomainPath configsDir configPath;
        in
          { value = configValue; path = configPath; domainPath = domainPath; }
      else null;
  
  # Discover all config files in the filesystem
  # Finds all *-config.nix files in the configs/ directory
  discoverConfigs = configsDir: configsPath:
    let
      # Check if configs directory exists first
      configsExist = safePathExists configsPath;
    in
      if !configsExist then
        []
      else
        let
          dir = builtins.readDir configsPath;

          # Find all *-config.nix files directly in configs/
          configFiles = builtins.filter (name:
            hasSuffix "-config.nix" name && dir.${name} == "regular"
          ) (builtins.attrNames dir);

          # Extract config names
          configNames = builtins.map (file:
            builtins.head (builtins.split "-config.nix" file)
          ) configFiles;

          # Remove duplicates (shouldn't be any, but safe)
          uniqueConfigs = builtins.foldl' (acc: name:
            if builtins.elem name acc then acc else acc ++ [name]
          ) [] configNames;
        in
          uniqueConfigs;
  
  # Merge config into correct structure based on discovered domain path
  # Example: ["system", "audio"] → { system = { audio = configValue; }; }
  mergeConfigIntoStructure = domainPath: configValue: baseConfig:
    let
      nestedConfig = if domainPath != []
        then builtins.foldl' (acc: key: { ${key} = acc; }) configValue (reverseList domainPath)
        else configValue;  # No domain, merge at top-level
    in
      recursiveUpdate baseConfig nestedConfig;

in
{
  # Load and merge all configs
  # Usage: loadSystemConfig configsDir systemConfigPath configsPath
  loadSystemConfig = configsDir: systemConfigPath: configsPath:
    let
      # 1. Load system-config if exists (for compatibility), otherwise empty set
      baseConfig = if builtins.pathExists systemConfigPath
        then import systemConfigPath
        else {};

      # 2. Dynamically discover all config files
      optionalConfigs = discoverConfigs configsDir configsPath;

      # 3. Load and merge all discovered configs
      # Order is important: later configs override earlier ones
      mergedConfig = builtins.foldl' (acc: configName:
        let
          loaded = loadConfig configName configsDir configsPath;
        in
          if loaded != null && loaded.value != {} then
            mergeConfigIntoStructure loaded.domainPath loaded.value acc
          else acc
      ) baseConfig optionalConfigs;
    in
      mergedConfig;

  # Get list of discovered configs (for reference/debugging)
  getDiscoveredConfigs = configsDir: discoverConfigs configsDir;

  # Export for debugging
  extractDomainPath = extractDomainPath;
  loadConfig = loadConfig;
  safeImport = safeImport;
  isValidConfig = isValidConfig;
  safePathExists = safePathExists;
  safeReadFile = safeReadFile;
}
