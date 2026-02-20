# Module configuration helper - provides automatic config path resolution
{ lib, systemConfig }:
let
  # Import module discovery for automatic config paths
  discovery = import ./discovery.nix { inherit lib; };
  discoveredModules = discovery.discoverAllModules;

  # Generate automatic APIs for all discovered modules
  moduleConfigAttrs = lib.listToAttrs (
    map (module: {
      name = module.name;
      value = {
        inherit (module) configPath enablePath apiPath;
        name = module.name;
        category = module.category;
        path = module.path;
      };
    }) discoveredModules
  );

  # SEMANTISCH KLAR GETRENNTE FUNKTIONEN:

  # 1. getModuleConfig: Holt CONFIG aus systemConfig (MIT template-config.nix defaults!)
  # getModuleConfig "network" → systemConfig.core.base.network (mit template defaults als Fallback)
  getModuleConfig = moduleName:
    let
      allNames = builtins.attrNames moduleConfigAttrs;
      suffixMatches = lib.filter (name: lib.hasSuffix ".${moduleName}" name) allNames;
      matchedModuleName = if suffixMatches != [] then builtins.head suffixMatches
                          else if builtins.hasAttr moduleName moduleConfigAttrs then moduleName
                          else null;
      metadata = if matchedModuleName == null then {} else moduleConfigAttrs.${matchedModuleName};
      
      # Get template defaults from template-config.nix if it exists
      templateDefaults = if metadata != {} && metadata ? path then
        let
          templateFile = "${metadata.path}/template-config.nix";
          # Check if file exists before trying to import
          templateExists = builtins.pathExists templateFile;
          templateContent = if templateExists then
            let
              templateImport = builtins.tryEval (import templateFile);
            in
              if templateImport.success then templateImport.value else {}
            else {};
        in
          templateContent
        else {};
      
      # Get config from systemConfig (user config files)
      systemConfigValue = if matchedModuleName == null then {}
        else lib.attrByPath (lib.splitString "." metadata.configPath) {} systemConfig;
      
      # Merge: template defaults -> systemConfig (user config)
      result = lib.recursiveUpdate templateDefaults systemConfigValue;
    in
      # ROBUST: Immer ein AttrSet zurückgeben, auch wenn etwas schief geht
      if builtins.isAttrs result then result else {};

  # 2. getModuleMetadata: Holt METADATA aus discovery
  # getModuleMetadata "network" → { name, path, configPath, apiPath, ... }
  getModuleMetadata = moduleName:
    let
      allNames = builtins.attrNames moduleConfigAttrs;
      suffixMatches = lib.filter (name: lib.hasSuffix ".${moduleName}" name) allNames;
      matchedModuleName = if suffixMatches != [] then builtins.head suffixMatches
                          else if builtins.hasAttr moduleName moduleConfigAttrs then moduleName
                          else null;
    in
      if matchedModuleName == null then {} else moduleConfigAttrs.${matchedModuleName};

  # 3. getCurrentModuleMetadata: Holt METADATA für das AKTUELLE Modul
  # getCurrentModuleMetadata ./.; → { name, path, configPath, apiPath, ... } für dieses Modul
  getCurrentModuleMetadata = modulePath:
    let
      # Extrahiere Modulname aus Pfad
      moduleName = builtins.baseNameOf (toString modulePath);
      # Finde passendes Modul in discoveredModules
      matchingModules = lib.filter (m: m.name == moduleName) discoveredModules;
    in
      if matchingModules == [] then {
        # Fallback wenn nicht gefunden
        name = moduleName;
        path = modulePath;
        configPath = "modules.${moduleName}";
        apiPath = "modules.${moduleName}";
        enablePath = "modules.${moduleName}.enable";
        category = "modules.${moduleName}";
      } else builtins.head matchingModules;

  # 4. getModuleApi: Holt API-Pfad für ein Modul
  # getModuleApi "cli-formatter" → "core.management.system-manager.submodules.cli-formatter.api"
  # getModuleApi "system-manager" → "core.management.system-manager.api"
  # Usage: config.${getModuleApi "module"}
  # Automatische Übersetzung: Runtime = config path, Build-Time = direkter API import
  getModuleApi = moduleName:
    let
      metadata = getModuleMetadata moduleName;
      apiPath = if metadata == {} then "" else metadata.apiPath;
    in
    # Magische Übersetzung: Zur Build-Time automatisch resolve
    if (builtins.tryEval builtins.derivation).success then
      # Build-Time: Discovery neu laufen und API direkt importieren
      let
        modules = discovery.discoverAllModules;
        targetModule = lib.findFirst (m: m.name == moduleName) null modules;
      in
      if targetModule == null then
        throw "Module ${moduleName} not found"
      else
        # Direktes API import zur Build-Time
        import "${targetModule.path}/api.nix" { inherit lib; }
    else
      # Runtime: Normales config access
      apiPath + ".api";

in
moduleConfigAttrs // {
  inherit getModuleConfig getModuleMetadata getCurrentModuleMetadata getModuleApi;
}
