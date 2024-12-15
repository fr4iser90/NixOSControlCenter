{ config, lib, pkgs, systemConfig, ... }:
{
  imports = [ 
      ./display-managers
      ./display-servers
      ./environments
      ./themes
    ];

  # DBus-Fix (könnte auch in display-servers/common.nix verschoben werden)
  services.dbus = {
    enable = true;
    implementation = "broker";
  };

  assertions = [
    {
      assertion = builtins.elem systemConfig.displayServer ["x11" "wayland" "hybrid"];
      message = "Invalid display server selection: ${systemConfig.displayServer}";
    }
    {
      assertion = builtins.elem systemConfig.desktop ["plasma" "gnome" "xfce"];
      message = "Invalid desktop environment: ${systemConfig.desktop}";
    }
    {
      assertion = builtins.elem systemConfig.displayManager ["sddm" "gdm" "lightdm"];
      message = "Invalid display manager: ${systemConfig.displayManager}";
    }
  ];
}