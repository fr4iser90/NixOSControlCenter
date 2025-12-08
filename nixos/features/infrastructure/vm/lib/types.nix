{ lib }:
with lib;
{
  vmConfig = types.submodule {
    options = {
      memory = mkOption {
        type = types.int;
        default = 4096;
        description = "RAM in MB";
      };
      cores = mkOption {
        type = types.int;
        default = 2;
        description = "CPU cores";
      };
      storage = {
        size = mkOption {
          type = types.int;
          default = 40;
          description = "Disk size in GB";
        };
      };
    };
  };
}