{ lib, ... }:

{
  fieldsToKeep = [
    "systemType"
    "hostName"
    "system"
    "allowUnfree"
    "users"
    "timeZone"
  ];

  fieldsToMigrate = {
    desktop = {
      targetFile = "desktop-config.nix";
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
      targetFile = "hardware-config.nix";
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
    packageModules = {
      targetFile = "packages-config.nix";
      structure = {
        preset = "packageModules.preset";
        packageModules = "packageModules.packageModules";
        additionalPackageModules = "packageModules.additionalPackageModules";
      };
    };
    locales = {
      targetFile = "localization-config.nix";
      structure = {
        locales = "locales";
        keyboardLayout = "keyboardLayout";
        keyboardOptions = "keyboardOptions";
      };
    };
    overrides = {
      targetFile = "overrides-config.nix";
      structure = {
        overrides.enableSSH = "overrides.enableSSH";
      };
    };
    hosting = {
      targetFile = "hosting-config.nix";
      structure = {
        email = "email";
        domain = "domain";
        certEmail = "certEmail";
      };
    };
    logging = {
      targetFile = "logging-config.nix";
      structure = {
        buildLogLevel = "buildLogLevel";
      };
    };
    network = {
      targetFile = "network-config.nix";
      structure = {
        enableFirewall = "enableFirewall";
        enablePowersave = "enablePowersave";
        networkManager.dns = "networkManager.dns";
      };
    };
  };
}
