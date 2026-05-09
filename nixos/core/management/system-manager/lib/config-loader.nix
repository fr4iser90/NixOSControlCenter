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
      
      # Filter out config file name and current directory (no more user-systemConfig/ directory)
      relevantParts = builtins.filter (p:
        !hasSuffix ".nix" p && p != "."
      ) pathComponents;

     # Normal case: remove top-level directory (systemConfig/), keep the module path
      domainPath = if builtins.length relevantParts >= 2
                    then builtins.tail relevantParts  # Remove "systemConfig", keep module path
                    else if builtins.length relevantParts == 1
                    then if builtins.head relevantParts == "systemConfig"
                         then []  # Configs in /etc/nixos/systemConfig/ → merge at top level
                         else relevantParts
                    else relevantParts;  # Empty or just module name
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
        configsPath  # ./systemConfig (relative to flake)
      ];

      # Find the first valid config file
      configResult = builtins.foldl' (acc: searchPath:
        if acc != null then acc  # Already found, keep it
        else
          let
            configPath = "${toString searchPath}/${configName}/config.nix";
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

  # Discover template-config.nix files from module directories
  # Scans core/ and modules/ subdirectories under the flake root
  discoverTemplates = configsDir:
    let
      discoverInDir = dir:
        let
          dirExists = pathExists dir;
        in
        if !dirExists then []
        else
          let
            dirContent = readDir dir;
            subDirs = builtins.attrNames (filterAttrs (name: type: type == "directory") dirContent);
            templatesInDir = builtins.filter (name: name == "template-config.nix" && dirContent.${name} == "regular") (builtins.attrNames dirContent);
            currentTemplates = builtins.map (file: dir + "/${file}") templatesInDir;
            recursiveTemplates = builtins.concatMap (subDir: discoverInDir (dir + "/${subDir}")) subDirs;
          in
            currentTemplates ++ recursiveTemplates;
    in
      (discoverInDir "${configsDir}/core") ++ (discoverInDir "${configsDir}/modules");

  # Extract domain path from a template file path
  # Unlike user configs, templates don't have a "systemConfig" prefix to strip
  # Example: core/base/network/template-config.nix → ["core", "base", "network"]
  extractTemplateDomainPath = configsDir: templatePath:
    let
      pathStr = toString templatePath;
      dirStr = toString configsDir;
      relativePath = if builtins.stringLength pathStr > builtins.stringLength dirStr
        then builtins.substring (builtins.stringLength dirStr + 1)
             (builtins.stringLength pathStr - builtins.stringLength dirStr - 1)
             pathStr
        else "";

      splitPath = builtins.split "/" relativePath;
      pathComponents = builtins.filter (p: builtins.isString p && p != "")
        (map (s: if builtins.isString s then s else null) splitPath);

      # Filter out template-config.nix file name (not matching hasSuffix ".nix" since it has a dash)
      relevantParts = builtins.filter (p:
        p != "template-config.nix" && p != "."
      ) pathComponents;

      # Use all parts as domain path (no tail - templates start at core/ or modules/)
      domainPath = if builtins.length relevantParts >= 1 then relevantParts else [];
    in
      domainPath;

  # Load a single template-config.nix file
  loadTemplate = templatePath: configsDir:
    let
      domainPath = extractTemplateDomainPath configsDir templatePath;
      loadedConfig = importNix templatePath;
    in
      { value = loadedConfig; path = templatePath; domainPath = domainPath; };

  # Load and merge all configs
  # Usage: loadSystemConfig configsDir configsPath
  loadSystemConfig = configsDir: configsPath:
    let
      # 1. Start with template defaults from module directories
      templatePaths = discoverTemplates configsDir;
      baseConfig = builtins.foldl' (acc: templatePath:
        let
          loaded = loadTemplate templatePath configsDir;
        in
          if loaded.value != {} then
            mergeConfigIntoStructure loaded.domainPath loaded.value acc
          else acc
      ) {} templatePaths;

      # 2. Dynamically discover all user config files
      optionalConfigs = discoverConfigs configsDir configsPath;

      # 3. Load and merge all discovered configs on top of templates
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
  getDiscoveredConfigs = configsDir: configsPath: discoverConfigs configsDir configsPath;

in
{
  loadSystemConfig = loadSystemConfig;
  getDiscoveredConfigs = getDiscoveredConfigs;
}
