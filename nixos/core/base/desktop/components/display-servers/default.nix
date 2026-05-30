{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  cfg = getModuleConfig "desktop";
  displayCfg = cfg.display or {};
  server = displayCfg.server or "wayland";
  desktopEnabled = cfg.enable or true;
in {
  # Import display server configurations based on selection
  # For hybrid setups, both x11 and wayland will be imported
  imports =
    lib.optionals desktopEnabled (
      lib.optional (server == "x11" || server == "hybrid")
        ./x11/default.nix
      ++ lib.optional (server == "wayland" || server == "hybrid")
        ./wayland/default.nix
    );

  # Base configuration for X11-based display servers
  # Only enabled if desktop is active and not using Wayland-only setup
  services.xserver = lib.mkIf (desktopEnabled && server != "wayland") {
    enable = true;
  };

  # Validate display server selection
  # Ensures only supported configurations are used
  assertions = lib.mkIf (cfg.enable or true) [{
    assertion = builtins.elem server ["x11" "wayland" "hybrid"];
    message = "Invalid display server: ${server}";
  }];
}