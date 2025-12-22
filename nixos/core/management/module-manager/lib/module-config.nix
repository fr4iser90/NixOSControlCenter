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

  # 1. getModuleConfig: Holt CONFIG aus systemConfig
  # getModuleConfig "network" → systemConfig.core.base.network
  getModuleConfig = moduleName:
    let
      allNames = builtins.attrNames moduleConfigAttrs;
      suffixMatches = lib.filter (name: lib.hasSuffix ".${moduleName}" name) allNames;
      matchedModuleName = if suffixMatches != [] then builtins.head suffixMatches
                          else if builtins.hasAttr moduleName moduleConfigAttrs then moduleName
                          else null;
      result = if matchedModuleName == null then {} else lib.attrByPath (lib.splitString "." moduleConfigAttrs.${matchedModuleName}.configPath) {} systemConfig;
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
  getModuleApi = moduleName:
    let
      metadata = getModuleMetadata moduleName;
    in
      if metadata == {} then "" else metadata.apiPath + ".api";

in
moduleConfigAttrs // {
  inherit getModuleConfig getModuleMetadata getCurrentModuleMetadata getModuleApi;
}
