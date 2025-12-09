{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.system.desktop or {};
  locCfg = systemConfig.system.localization or {};
  # CRITICAL: Use absolute path to deployed location, not relative (which resolves to store)
  userConfigFile = "/etc/nixos/core/system/desktop/desktop-config.nix";
  symlinkPath = "/etc/nixos/configs/desktop-config.nix";
  # Use API (like cli-formatter.api)
  configHelpers = config.core.management.system-manager.api.configHelpers;
  defaultConfig = ''
{
  desktop = {
    enable = false;
    environment = "plasma";
    display = {
      manager = "sddm";
      server = "wayland";
      session = "plasma";
    };
    theme = {
      dark = true;
    };
  };
}
'';
  
  # Use keyboard settings from localization module
  keyboardLayout = locCfg.keyboardLayout or "us";
  keyboardOptions = locCfg.keyboardOptions or "";
in
{
  config = lib.mkMerge [
    {
      # Create symlink on activation (always, not only when enabled)
      # Uses central API from system-manager (professional pattern)
      system.activationScripts.desktop-config-symlink = 
        configHelpers.setupConfigFile symlinkPath userConfigFile defaultConfig;
    }
    (lib.mkIf (cfg.enable or false) {
      environment = {
        variables = {
          XKB_DEFAULT_LAYOUT = keyboardLayout;
          XKB_DEFAULT_OPTIONS = keyboardOptions;
        };
        sessionVariables = {
          XKB_DEFAULT_LAYOUT = keyboardLayout;
          XKB_DEFAULT_OPTIONS = keyboardOptions;
        };
      };

      services.dbus = {
        enable = true;
        implementation = "broker";
      };

      assertions = [
        {
          assertion = cfg.display.server or "wayland" == "wayland" ||
                      cfg.display.server == "x11" ||
                      cfg.display.server == "hybrid";
          message = "Invalid display server selection: ${cfg.display.server or "none"}";
        }
        {
          assertion = cfg.environment or "plasma" == "plasma" ||
                      cfg.environment == "gnome" ||
                      cfg.environment == "xfce";
          message = "Invalid desktop environment: ${cfg.environment or "none"}";
        }
        {
          assertion = cfg.display.manager or "sddm" == "sddm" ||
                      cfg.display.manager == "gdm" ||
                      cfg.display.manager == "lightdm";
          message = "Invalid display manager: ${cfg.display.manager or "none"}";
        }
      ];
    })
  ];
}
