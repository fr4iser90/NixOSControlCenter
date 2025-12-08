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

      binary = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Name of the binary to execute (if different from check name)";
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
            level = lib.mkOption {
              type = lib.types.enum [ "error" "warning" "info" "success" ];
              default = "info";
              description = "Severity level of the check result";
            };
          };
        });
        description = "Function to validate check results";
      };
    };
  };
}