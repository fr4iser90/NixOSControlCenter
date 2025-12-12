{ config, lib, pkgs, systemConfig, ... }:
let
  cfg = systemConfig.system.desktop or {};
  locCfg = systemConfig.system.localization or {};
  configHelpers = import ../../management/module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  # Use the template file as default config
  defaultConfig = builtins.readFile ./desktop-config.nix;
  
  # Use keyboard settings from localization module
  keyboardLayout = locCfg.keyboardLayout or "us";
  keyboardOptions = locCfg.keyboardOptions or "";
in
{
  config = lib.mkMerge [
    # Create config on activation (always runs)
    # Uses new external config system
    (configHelpers.createModuleConfig {
      moduleName = "desktop";
      defaultConfig = defaultConfig;
    })
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
