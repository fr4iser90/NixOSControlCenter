let
  pkgs = import <nixpkgs> {};
  nixosTest = import (pkgs.path + "/nixos/tests/make-test-python.nix");
in

nixosTest {
  name = "control-center-vm-basic";

  nodes.machine = { pkgs, ... }: {
    imports = [ 
      ../modules/control-center
    ];

    # Basis-Konfiguration
    services.control-center = {
      enable = true;
      port = 8000;
    };

    # Enable VNC viewer
    virtualisation = {
        graphics = true;  # Dies aktiviert die GUI
        memorySize = 1024;
    };
    
    # Desktop-Umgebung
    services.xserver = {
      enable = true;
      
      # XFCE als Desktop
      desktopManager.xfce.enable = true;
      displayManager = {
        defaultSession = "xfce";
        # Auto-Login
        lightdm = {
          enable = true;
          greeter.enable = false;
        };
        autoLogin = {
          enable = true;
          user = "test";
        };
      };
    };

    # Test-User
    users.users.test = {
      isNormalUser = true;
      password = "test";
      extraGroups = [ "wheel" ];
    };

    # X11 Konfiguration
    services.xserver.displayManager.sessionCommands = ''
      ${pkgs.xorg.xhost}/bin/xhost +local:
    '';

    # GUI-Pakete
    environment.systemPackages = with pkgs; [
      gtk4
      xorg.xhost
    ];
  };

  testScript = ''
    start_all()
    
    with subtest("basic-setup"):
        machine.wait_for_unit("multi-user.target")
        machine.succeed("systemctl start control-center")
        machine.succeed("systemctl is-active control-center")
        machine.succeed("journalctl -u control-center | grep 'Control Center running'")

    with subtest("gui-setup"):
        # Warte auf X11
        machine.wait_for_x()
        
        # Warte auf XFCE
        machine.wait_until_succeeds("pgrep xfce4-session")
        
        # Mache einen Screenshot vom Desktop
        machine.screenshot("desktop")
        
        # Starte deine GUI (wenn vorhanden)
        machine.succeed("sudo -u test DISPLAY=:0 control-center-gui &")
        
        # Warte kurz und mache noch einen Screenshot
        machine.sleep(5)
        machine.screenshot("control-center")
  '';
}