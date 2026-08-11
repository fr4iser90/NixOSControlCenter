{ lib, ... }:

{
  description = "v2.0 → v2.1: set system.platform from live uname -m (no silent x86 fallback)";

  fieldsToKeep = [];

  fieldsToMigrate = {
    systemManager = {
      targetFile = "core/management/system-manager/config.nix";
      inject = {
        configVersion = "2.1";
        # platform value is applied at migrate time from uname (see migration.nix)
      };
    };
  };

  layoutConversion = false;

  # Hint for migration engine / docs
  liveInject = {
    "system.platform" = "uname-m"; # aarch64|arm64 → aarch64-linux; else x86_64-linux
  };
}
