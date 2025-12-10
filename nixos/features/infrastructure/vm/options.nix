{ lib, ... }:

let
  moduleVersion = "1.0";
  stateDir = "/var/lib/virt";
in {
  options.features.infrastructure.vm = {
    # Version metadata (internal)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Feature version";
    };

    # Dependencies this module has
    _dependencies = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "system-checks" "command-center" ];
      internal = true;
      description = "Modules this feature depends on";
    };

    # Conflicts this module has
    _conflicts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      internal = true;
      description = "Modules that conflict with this feature";
    };

    enable = lib.mkEnableOption "VM Manager";
    
    storage.enable = lib.mkEnableOption "Storage Management for VMs";
    
    stateDir = lib.mkOption {
      type = lib.types.path;
      default = stateDir;
      description = "Base directory for virtualization state";
    };
  };
}

