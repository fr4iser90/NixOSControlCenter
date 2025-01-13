{ config, lib, pkgs, systemConfig, ... }:
{
  imports = if (systemConfig.desktop.enable or false) then [ 
    ./display-managers
    ./display-servers
    ./environments
    ./audio
    ./themes
  ] else [];

  # Globale Tastaturkonfiguration für alle Display-Server
  console.keyMap = systemConfig.keyboardLayout or "us";
  
  environment = lib.mkIf (systemConfig.desktop.enable or false) {
    variables = {
      XKB_DEFAULT_LAYOUT = systemConfig.keyboardLayout or "us";
      XKB_DEFAULT_OPTIONS = systemConfig.keyboardOptions or "";
    };
    sessionVariables = {
      XKB_DEFAULT_LAYOUT = systemConfig.keyboardLayout or "us";
      XKB_DEFAULT_OPTIONS = systemConfig.keyboardOptions or "";
    };
  };

  services.xserver = lib.mkIf (systemConfig.desktop.enable or false) {
    xkb = {
      layout = systemConfig.keyboardLayout or "us";
      options = systemConfig.keyboardOptions or "";
    };
  };

  services.dbus = lib.mkIf (systemConfig.desktop.enable or false) {
    enable = true;
    implementation = "broker";
  };

  assertions = lib.mkIf (systemConfig.desktop.enable or false) [
    {
      assertion = systemConfig.desktop.display.server or "wayland" == "wayland" ||
                  systemConfig.desktop.display.server == "x11" ||
                  systemConfig.desktop.display.server == "hybrid";
      message = "Invalid display server selection: ${systemConfig.desktop.display.server or "none"}";
    }
    {
      assertion = systemConfig.desktop.environment or "plasma" == "plasma" ||
                  systemConfig.desktop.environment == "gnome" ||
                  systemConfig.desktop.environment == "xfce";
      message = "Invalid desktop environment: ${systemConfig.desktop.environment or "none"}";
    }
    {
      assertion = systemConfig.desktop.display.manager or "sddm" == "sddm" ||
                  systemConfig.desktop.display.manager == "gdm" ||
                  systemConfig.desktop.display.manager == "lightdm";
      message = "Invalid display manager: ${systemConfig.desktop.display.manager or "none"}";
    }
  ];
}