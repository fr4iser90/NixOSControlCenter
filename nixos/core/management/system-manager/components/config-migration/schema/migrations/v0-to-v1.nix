{ lib, ... }:

{
  # ALLE Felder migrieren — system-config.nix wird komplett abgelöst
  # Jeder targetFile darf NUR EINMAL vorkommen (kein Merge-Konflikt)
  fieldsToKeep = [];

  fieldsToMigrate = {
    desktop = {
      targetFile = "core/base/desktop/config.nix";
      structure = {
        desktop = {
          enable = "desktop.enable";
          environment = "desktop.environment";
          display.manager = "desktop.display.manager";
          display.server = "desktop.display.server";
          display.session = "desktop.display.session";
          theme.dark = "desktop.theme.dark";
          audio = "desktop.audio";
        };
      };
    };
    hardware = {
      targetFile = "core/base/hardware/config.nix";
      fieldMappings = {
        "hardware.memory" = "hardware.ram";
      };
      structure = {
        hardware = {
          cpu = "hardware.cpu";
          gpu = "hardware.gpu";
          ram.sizeGB = "hardware.ram.sizeGB";
        };
      };
    };
    packages = {
      targetFile = "core/base/packages/config.nix";
      rawSource = "{packageModules, overrides}";
      rawUnwrap = true;
    };
    localization = {
      targetFile = "core/base/localization/config.nix";
      rawSource = "{timeZone, locales, keyboardLayout, keyboardOptions, email, domain}";
      rawUnwrap = true;
    };
    network = {
      targetFile = "core/base/network/config.nix";
      structure = {
        hostName = "hostName";
        networkManager.dns = "networkManager.dns";
      };
    };
    users = {
      targetFile = "core/base/user/config.nix";
      rawSource = "users";
      rawUnwrap = true;
    };
    systemManager = {
      targetFile = "core/management/system-manager/config.nix";
      rawSource = "{systemType, allowUnfree, system, buildLogLevel, features}";
      rawUnwrap = true;
    };
  };
}
