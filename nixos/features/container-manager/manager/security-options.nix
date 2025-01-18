{ lib, ... }:

{
  options = {
    security.subUidRanges = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.int);
      default = [];
      description = "Defines sub-UID ranges for container users.";
    };

    security.subGidRanges = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.int);
      default = [];
      description = "Defines sub-GID ranges for container users.";
    };

    security.subUidOwners = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of users who own sub-UID ranges.";
    };

    security.subGidOwners = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of users who own sub-GID ranges.";
    };
  };
}
