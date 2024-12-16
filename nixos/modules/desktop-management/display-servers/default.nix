# display-servers/default.nix
{ config, lib, pkgs, systemConfig, ... }:

{
  imports = 
    lib.optional (systemConfig.displayServer == "x11" || systemConfig.displayServer == "hybrid") 
      (./x11/default.nix)  # Expliziter Pfad zum default.nix
    ++ lib.optional (systemConfig.displayServer == "wayland" || systemConfig.displayServer == "hybrid") 
      (./wayland/default.nix);  # Expliziter Pfad zum default.nix

  # Gemeinsame Basis-Konfiguration für alle Display Server
  services.xserver = lib.mkIf (systemConfig.displayServer != "wayland") {
    enable = true;
  };
  
  # Optional: Validierung
  assertions = [
    {
      assertion = builtins.elem systemConfig.displayServer ["x11" "wayland" "hybrid"];
      message = "Invalid display server: ${systemConfig.displayServer}";
    }
  ];
}