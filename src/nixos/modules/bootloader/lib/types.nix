{ lib }:

with lib;

{
  bootEntry = types.submodule {
    options = {
      generation = mkOption {
        type = types.int;
        description = "Generation number";
      };
      
      title = mkOption {
        type = types.str;
        description = "Entry title";
      };
      
      sortKey = mkOption {
        type = types.str;
        default = "nixos";
        description = "Sort key for ordering";
      };
      
      locked = mkOption {
        type = types.bool;
        default = false;
        description = "Whether entry is locked";
      };
    };
  };

  entryConfig = types.submodule {
    options = {
      dataPath = mkOption {
        type = types.str;
        default = "/boot/loader/entries";
        description = "Path to boot entries";
      };
      
      limit = mkOption {
        type = types.int;
        default = 5;
        description = "Maximum number of entries to keep";
      };
    };
  };
}