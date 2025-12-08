{ lib, ... }:

let
  moduleVersion = "1.0";
in {
  options.systemConfig.hardware = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Hardware module version";
    };

    cpu = lib.mkOption {
      type = lib.types.enum [
        "intel"
        "intel-core"
        "intel-xeon"
        "amd"
        "amd-ryzen"
        "amd-epyc"
        "vm-cpu"
        "none"
      ];
      default = "none";
      description = "CPU type configuration";
    };

    gpu = lib.mkOption {
      type = lib.types.enum [
        "nvidia"
        "amd"
        "intel"
        "nvidia-intel"
        "nvidia-amd"
        "intel-igpu"
        "nvidia-sli"
        "amd-crossfire"
        "nvidia-optimus"
        "vm-gpu"
        "amd-intel"
        "qxl-virtual"
        "virtio-virtual"
        "basic-virtual"
        "amd-amd"
        "none"
      ];
      default = "none";
      description = "GPU type configuration";
    };

    ram = {
      sizeGB = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "RAM size in GB (null = auto-detect via system-checks or disabled)";
      };
    };
  };
}

