{ config, lib, pkgs, systemConfig, ... }:

let
  desktopCfg = lib.attrByPath ["core" "base" "desktop"] {} systemConfig;
  displayCfg = desktopCfg.display or {};
  server = displayCfg.server or "wayland";
in {
  # Import display server configurations based on selection
  # For hybrid setups, both x11 and wayland will be imported
  imports =
    lib.optional (server == "x11" || server == "hybrid")
      ./x11/default.nix  # Load X11 only when needed
    ++
    lib.optional (server == "wayland" || server == "hybrid")
      ./wayland/default.nix;  # Load Wayland when needed

  # Base configuration for X11-based display servers
  # Only enabled if not using Wayland-only setup
  services.xserver = lib.mkIf (server != "wayland") {
    enable = true;
  };

  # Validate display server selection
  # Ensures only supported configurations are used
  assertions = lib.mkIf (desktopCfg.enable or true) [{
    assertion = builtins.elem server ["x11" "wayland" "hybrid"];
    message = "Invalid display server: ${server}";
  }];
}