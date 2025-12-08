{ lib, ... }:

let
  moduleVersion = "1.0";
in {
  options.systemConfig.packages = {
    # Version metadata (REQUIRED)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Packages module version";
    };
    
    # Package modules list
    packageModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of package modules to enable";
    };
    
    # Additional package modules
    additionalPackageModules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional package modules to enable (beyond packageModules)";
    };
    
    # Preset selection
    preset = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Preset to use (e.g., 'gaming-desktop', 'dev-workstation')";
    };
  };
}

