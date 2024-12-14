{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.control-center;
  
  # Import GUI und Service Module
  gui = import ./gui.nix { inherit pkgs cfg; };
  service = import ./service.nix { inherit pkgs cfg; pythonWithTk = gui.pythonWithTk; };

in {
  options.services.control-center = {
    enable = mkEnableOption "NixOS Control Center";
    
    port = mkOption {
      type = types.port;
      default = 8000;
      description = "Port für den Control Center Service";
    };
  };

  config = mkIf cfg.enable {
    # Service Definition
    systemd.services.control-center = service;

    # GUI-Programm und Abhängigkeiten installieren
    environment.systemPackages = [
      gui.control-center-gui
      gui.pythonWithTk
    ];
  };
}