{ config, lib, pkgs, systemConfig, ... }:
{
  imports = if systemConfig.desktop.enable then [ 
    ./display-managers
    ./display-servers
    ./environments
    ./audio
    #./themes
  ] else [];

  # Globale Tastaturkonfiguration für alle Display-Server
  console.keyMap = systemConfig.keyboardLayout;
  
  environment = lib.mkIf systemConfig.desktop.enable {
    variables = {
      XKB_DEFAULT_LAYOUT = systemConfig.keyboardLayout;
      XKB_DEFAULT_OPTIONS = systemConfig.keyboardOptions;
    };
    sessionVariables = {
      XKB_DEFAULT_LAYOUT = systemConfig.keyboardLayout;
      XKB_DEFAULT_OPTIONS = systemConfig.keyboardOptions;
    };
  };

  services.xserver = lib.mkIf systemConfig.desktop.enable {
    xkb = {
      layout = systemConfig.keyboardLayout;
      options = systemConfig.keyboardOptions;
    };
  };

  services.dbus = lib.mkIf systemConfig.desktop.enable {
    enable = true;
    implementation = "broker";  # dbus | broker
  };

  assertions = lib.mkIf systemConfig.desktop.enable [
    {
      assertion = builtins.elem systemConfig.desktop.display.server ["x11" "wayland" "hybrid"];
      message = "Invalid display server selection: ${systemConfig.desktop.display.server}";
    }
    {
      assertion = builtins.elem systemConfig.desktop.environment ["plasma" "gnome" "xfce"];
      message = "Invalid desktop environment: ${systemConfig.desktop.environment}";
    }
    {
      assertion = builtins.elem systemConfig.desktop.display.manager ["sddm" "gdm" "lightdm"];
      message = "Invalid display manager: ${systemConfig.desktop.display.manager}";
    }
  ];
}