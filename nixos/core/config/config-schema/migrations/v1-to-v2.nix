{ lib, ... }:

{
  # Migrations-Plan von v1.0 zu v2.0
  # Definiert WIE migriert wird - komplett Schema-basiert!
  
  # Felder die in system-config.nix bleiben (required fields für v2.0)
  fieldsToKeep = [
    "systemType"
    "hostName"
    "system"
    "allowUnfree"
    "users"
    "timeZone"
  ];
  
  # Felder die in separate Config-Dateien migriert werden
  fieldsToMigrate = {
    "desktop" = {
      targetFile = "configs/desktop-config.nix";
      structure = {
        desktop = {
          enable = "desktop.enable";
          environment = "desktop.environment";
          display = {
            manager = "desktop.display.manager";
            server = "desktop.display.server";
            session = "desktop.display.session";
          };
          theme = {
            dark = "desktop.theme.dark";
          };
          audio = "desktop.audio";
        };
      };
    };
    
    "hardware" = {
      targetFile = "configs/hardware-config.nix";
      structure = {
        hardware = {
          cpu = "hardware.cpu";
          gpu = "hardware.gpu";
          ram = {
            sizeGB = "hardware.ram.sizeGB";  # Falls vorhanden
          };
        };
      };
      # Feld-Mappings (v1.0 -> v2.0)
      fieldMappings = {
        "hardware.memory.sizeGB" = "hardware.ram.sizeGB";
      };
    };
    
    "features" = {
      targetFile = "configs/features-config.nix";
      structure = {
        features = {
          "system-logger" = "features.system-logger";
          "system-checks" = "features.system-checks";
          "system-updater" = "features.system-updater";
          "ssh-client-manager" = "features.ssh-client-manager";
          "ssh-server-manager" = "features.ssh-server-manager";
          "bootentry-manager" = "features.bootentry-manager";
          "homelab-manager" = "features.homelab-manager";
          "vm-manager" = "features.vm-manager";
          "ai-workspace" = "features.ai-workspace";
        };
      };
    };
    
    "packageModules" = {
      targetFile = "configs/packages-config.nix";
      structure = {
        packageModules = "packageModules";
        preset = "preset";
        additionalPackageModules = "additionalPackageModules";
      };
      # Spezielle Konvertierung: Attrset -> Array (wird in Migration behandelt)
      conversion = "attrset-to-array";
    };
    
    "locales" = {
      targetFile = "configs/localization-config.nix";
      structure = {
        locales = "locales";
        keyboardLayout = "keyboardLayout";
        keyboardOptions = "keyboardOptions";
      };
    };
    
    "email" = {
      targetFile = "configs/hosting-config.nix";
      structure = {
        email = "email";
        domain = "domain";
        certEmail = "certEmail";
      };
    };
    
    "overrides" = {
      targetFile = "configs/overrides-config.nix";
      structure = {
        overrides = {
          enableSSH = "overrides.enableSSH";
          # enableSteam removed: Steam is now enabled via the "gaming" package feature
        };
      };
    };
    
    "buildLogLevel" = {
      targetFile = "configs/logging-config.nix";
      structure = {
        buildLogLevel = "buildLogLevel";
      };
    };
    
    "enableFirewall" = {
      targetFile = "configs/network-config.nix";
      structure = {
        enableFirewall = "enableFirewall";
        enablePowersave = "enablePowersave";
        networkManager = {
          dns = "networkManager.dns";
        };
      };
    };
  };
}

