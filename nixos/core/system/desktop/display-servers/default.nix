# display-servers/default.nix
{ config, lib, pkgs, systemConfig, ... }:

{
  # Import display server configurations based on selection
  # For hybrid setups, both x11 and wayland will be imported
  imports = 
    lib.optional (systemConfig.system.desktop.display.server == "x11" || 
                 systemConfig.system.desktop.display.server == "hybrid") 
      ./x11/default.nix  # Load X11 only when needed
    ++ 
    lib.optional (systemConfig.system.desktop.display.server == "wayland" || 
                 systemConfig.system.desktop.display.server == "hybrid") 
      ./wayland/default.nix;  # Load Wayland when needed

  # Base configuration for X11-based display servers
  # Only enabled if not using Wayland-only setup
  services.xserver = lib.mkIf (systemConfig.system.desktop.display.server != "wayland") {
    enable = true;
  };
  
  # Validate display server selection
  # Ensures only supported configurations are used
  assertions = lib.mkIf systemConfig.system.desktop.enable [{
    assertion = builtins.elem systemConfig.system.desktop.display.server ["x11" "wayland" "hybrid"];
    message = "Invalid display server: ${systemConfig.system.desktop.display.server}";
  }];
}