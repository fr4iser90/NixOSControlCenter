# modules/system-management/preflight/lib/types.nix
{ lib, ... }:

{
  checkType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Name of the check";
      };

      description = lib.mkOption {
        type = lib.types.str;
        description = "Detailed description of what this check validates";
      };

      check = lib.mkOption {
        type = lib.types.package;
        description = "The actual check script";
      };

      validate = lib.mkOption {
        type = lib.types.functionTo (lib.types.submodule {
          options = {
            success = lib.mkOption {
              type = lib.types.bool;
              description = "Whether the check passed";
            };
            message = lib.mkOption {
              type = lib.types.str;
              description = "Human readable result message";
            };
            details = lib.mkOption {
              type = lib.types.attrs;
              description = "Detailed check results";
              default = {};
            };
          };
        });
        description = "Function to validate check results";
      };
    };
  };
}