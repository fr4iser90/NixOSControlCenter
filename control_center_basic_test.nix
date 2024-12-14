{ pkgs ? import <nixpkgs> {} }:

let
  nixosTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
in

nixosTest {
  name = "control-center-module";

  # Definiere die Test-Maschine
  nodes.machine = { config, pkgs, ... }: {
    imports = [ 
      ../modules/control-center  # Dein Modul
    ];

    # Test-Konfiguration
    services.control-center = {
      enable = true;
      port = 8000;
      # weitere Modul-Optionen
    };

    # Benötigte Pakete für Tests
    environment.systemPackages = with pkgs; [
      python3
      gtk4
      curl
      jq  # Für JSON-Verarbeitung
    ];

    # Aktiviere benötigte Services
    services.dbus.enable = true;
    services.xserver.enable = true;
  };

  # Der eigentliche Test in Python
  testScript = ''
    import json

    start_all()

    with subtest("Basis-Setup"):
        # Warte auf System-Start
        machine.wait_for_unit("multi-user.target")
        machine.wait_for_unit("control-center.service")
        
        # Prüfe ob Service läuft
        machine.succeed("systemctl is-active control-center.service")

    with subtest("API-Tests"):
        # Teste API-Endpunkte
        status = machine.succeed("curl -s http://localhost:8000/api/status")
        assert json.loads(status)["status"] == "running"

        # Teste Konfiguration
        config = machine.succeed("curl -s http://localhost:8000/api/config")
        config_data = json.loads(config)
        assert config_data["port"] == 8000

    with subtest("GUI-Tests"):
        # Starte GUI
        machine.succeed("control-center-gui &")
        machine.wait_until_succeeds("pgrep -f control-center-gui")
        
        # Prüfe GTK-Prozess
        machine.succeed("ps aux | grep gtk")

    with subtest("Konfigurationsänderungen"):
        # Teste Konfigurationsänderungen
        machine.succeed("""
            cat > /etc/nixos/configuration.nix <<EOF
            { config, ... }:
            {
              services.control-center.port = 8001;
            }
            EOF
        """)
        
        # Teste Reload
        machine.succeed("systemctl reload control-center")
        
        # Prüfe neue Konfiguration
        new_config = machine.succeed("curl -s http://localhost:8001/api/config")
        assert json.loads(new_config)["port"] == 8001
  '';
}