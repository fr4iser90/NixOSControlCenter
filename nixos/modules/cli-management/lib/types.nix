{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.cli-management;
in {
  # CLI Command Type
  cliCommandType = types.submodule {
    options = {
      category = mkOption {
        type = types.enum (attrNames cfg.categories);
        description = "Command category";
      };

      name = mkOption {
        type = types.str;
        description = "Command name";
      };

      description = mkOption {
        type = types.str;
        default = "";
        description = "Short command description";
      };

      longDescription = mkOption {
        type = types.str;
        default = "";
        description = "Detailed command description";
      };

      examples = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Usage examples";
      };

      script = mkOption {
        type = types.str;
        description = "The actual command script";
      };
    };
  };
}