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
  
  # Helper: Read directory with error handling
  readDir = path:
    let result = builtins.tryEval (builtins.readDir path);
    in if result.success then result.value else {};

  # Helper: Check if path exists with error handling
  pathExists = path:
    let result = builtins.tryEval (builtins.pathExists path);
    in if result.success then result.value else false;

  # Helper: Read file with error handling
  readFile = path:
    let result = builtins.tryEval (builtins.readFile path);
    in if result.success then result.value else "";

  # Helper: Import nix file with error handling
  importNix = path:
    let result = builtins.tryEval (import path);
    in if result.success then result.value else {};
  
  # Extract domain path from file path
  # Example: core/system/audio/config.nix → ["system" "audio"]
  # Example: modules/infrastructure/vm/config.nix → ["infrastructure" "vm"]
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
      
      # Filter out config file name and current directory (no more user-configs/ directory)
      relevantParts = builtins.filter (p:
        !hasSuffix ".nix" p && p != "."
      ) pathComponents;

      # Normal case: remove top-level directory (configs/), keep the module path
      domainPath = if builtins.length relevantParts >= 2
                   then builtins.tail relevantParts  # Remove "configs", keep module path
                   else if builtins.length relevantParts == 1 && builtins.head relevantParts == "configs"
                   then []  # Configs in /etc/nixos/configs/ → merge at top level
                   else relevantParts;  # Just module name, no domain (legacy)
    in
      domainPath;
  
  # Check if config file is valid (exists, not empty, starts with '{')
  isValidConfig = path:
    let
      exists = pathExists path;
      content = readFile path;
      trimmed = builtins.replaceStrings [" " "\n" "\t" "\r"] ["" "" "" ""] content;
      startsWithBrace = builtins.stringLength trimmed >= 2 && builtins.substring 0 1 trimmed == "{";
    in
      exists && startsWithBrace;
  
  
  # Load a single config file
  # Returns: { value = <config-value>; path = <found-path>; domainPath = [<domain>, ...]; } or null
  loadConfig = configName: configsDir: configsPath:
    let
      # Search paths: Only flake configs (relative to flake root)
      searchPaths = [
        configsPath  # ./configs (relative to flake)
      ];

      # Find the first valid config file
      configResult = builtins.foldl' (acc: searchPath:
        if acc != null then acc  # Already found, keep it
        else
          let
            configPath = searchPath + "/" + configName + "/config.nix";
    in
      if builtins.pathExists configPath && isValidConfig configPath then
        let
          loadedConfig = importNix configPath;
          configValue = loadedConfig;
          domainPath = extractDomainPath configsDir configPath;
        in
          { value = configValue; path = configPath; domainPath = domainPath; }
            else null
      ) null searchPaths;
    in
      configResult;
  
  # Discover all config files in the filesystem
  # Recursively finds all config.nix files in nested directory structure
  discoverConfigs = configsDir: configsPath:
    let
      # Check if configs directory exists first
      configsExist = pathExists configsPath;
    in
      if !configsExist then
        []
      else
        let
          # Recursively find all config.nix files
          findConfigs = currentDir:
            let
              dir = builtins.readDir currentDir;
              subDirs = builtins.attrNames (filterAttrs (name: type: type == "directory") dir);
              configFiles = builtins.filter (name: name == "config.nix" && dir.${name} == "regular") (builtins.attrNames dir);
              currentConfigs = builtins.map (file: currentDir + "/${file}") configFiles;
              recursiveConfigs = builtins.concatMap (subDir: findConfigs (currentDir + "/${subDir}")) subDirs;
            in
              currentConfigs ++ recursiveConfigs;

          allConfigPaths = findConfigs configsPath;

          # Extract config names (relative path without "config.nix")
          configNames = builtins.map (path:
            let
              pathStr = toString path;
              dirStr = toString configsPath;
              relativePath = builtins.substring (builtins.stringLength dirStr + 1)
                             (builtins.stringLength pathStr - builtins.stringLength dirStr - 1 - builtins.stringLength "/config.nix")
                             pathStr;
            in
              relativePath
          ) allConfigPaths;

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
  # Usage: loadSystemConfig configsDir configsPath
  loadSystemConfig = configsDir: configsPath:
    let
      # 1. Start with empty base config (no more system-config.nix)
      baseConfig = {};

      # 2. Dynamically discover all config files
      optionalConfigs = discoverConfigs configsDir configsPath;

      # 3. Load and merge all discovered configs
      # Order is important: later configs override earlier ones
      mergedConfig = builtins.foldl' (acc: configName:
        let
          loaded = loadConfig configName configsDir configsPath;
        in
          if loaded != null && loaded.value != {} then
            let
              newAcc = mergeConfigIntoStructure loaded.domainPath loaded.value acc;
            in
              newAcc
          else
            acc
      ) baseConfig optionalConfigs;
    in
      mergedConfig;

  # Get list of discovered configs (for reference/debugging)
  getDiscoveredConfigs = configsDir: discoverConfigs configsDir;

  # Export for debugging
  extractDomainPath = extractDomainPath;
  loadConfig = loadConfig;
  importNix = importNix;
  isValidConfig = isValidConfig;
  pathExists = pathExists;
  readFile = readFile;
}
