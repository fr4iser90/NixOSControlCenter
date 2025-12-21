# 🎯 External config creation - no more symlinks!
# Creates activation scripts for external config setup
{ pkgs, lib }:

let
  # 🏗️ AUTOMATIC MODULE FRAMEWORK
  # Automatically generates module paths from filesystem structure

  # Get module info from current directory
  getModuleInfo = modulePath: rec {
    # Extract name from directory name
    name = lib.last (lib.splitString "/" (toString modulePath));

    # Extract category from parent directory
    category = lib.last (lib.splitString "/" (toString (dirOf modulePath)));

    # Extract parent category (modules/core/etc)
    parentCategory = lib.last (lib.splitString "/" (toString (dirOf (dirOf modulePath))));

    # Auto-generated paths
    fullPath = "${parentCategory}.${category}.${name}";
    optionsPath = fullPath;
    configPath = fullPath;
  };

  # Module configuration factory
  mkModuleConfig = modulePath: let
    info = getModuleInfo modulePath;
  in {
    # Module metadata
    inherit (info) name category parentCategory fullPath optionsPath configPath;

    # Utility functions
    mkOptionsPath = "options.${info.optionsPath}";
    mkConfigPath = "config.${info.configPath}";
  };


  createModuleConfig = { moduleName, defaultConfig }: {
    # Configs are now created manually in nested structure
    # Templates remain in modules for reference but no activation scripts needed
  };
in
{
  inherit createModuleConfig mkModuleConfig getModuleInfo;
}
 