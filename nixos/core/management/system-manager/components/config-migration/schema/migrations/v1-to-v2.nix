{ lib, ... }:

{
  description = "Bump to v2 dual-layout; keep split on-disk, inject layout field";

  # v1 split stays split; only metadata changes
  fieldsToKeep = [];

  fieldsToMigrate = {
    systemManager = {
      targetFile = "core/management/system-manager/config.nix";
      # Merge into existing system-manager leaf
      inject = {
        configVersion = "2.0";
        layout = "split";
      };
    };
  };

  # Layout conversion (split ↔ monolith) is handled by ncc-config-layout, not this version bump
  layoutConversion = false;
}
