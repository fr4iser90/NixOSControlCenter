{ lib, ... }:

let
  featureVersion = "1.0";
  stateDir = "/var/lib/virt";
in {
  options.features.vm-manager = {
    # Version metadata (internal)
    _version = lib.mkOption {
      type = lib.types.str;
      default = featureVersion;
      internal = true;
      description = "Feature version";
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

