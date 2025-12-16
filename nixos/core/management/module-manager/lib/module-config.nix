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

  # Helper function to get module config, preferring suffix matches for core modules
  getModuleConfig = moduleName:
    let
      allNames = builtins.attrNames moduleConfigAttrs;
      # Prefer suffix match over exact match (core modules have full paths like "core.base.network")
      suffixMatches = lib.filter (name: lib.hasSuffix ".${moduleName}" name) allNames;
      matchedModuleName = if suffixMatches != [] then builtins.head suffixMatches
                          else if builtins.hasAttr moduleName moduleConfigAttrs then moduleName
                          else null;
    in
      if matchedModuleName == null then {} else lib.attrByPath (lib.splitString "." moduleConfigAttrs.${matchedModuleName}.configPath) {} systemConfig;

in
moduleConfigAttrs // {
  getModuleConfig = getModuleConfig;
}
