{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # KDE Connect Basis
    kdePackages.kdeconnect-kde
    
    # Screen Sharing und Remote-Zugriff
    kdePackages.krfb   # KDE Remote Desktop
    kdePackages.krdc   # KDE Remote Desktop Client
    kdePackages.plasma-browser-integration
    kdePackages.qtwebengine
    
    # Multimedia-Integration
#    kdePackages.plasma-pa  # Pulseaudio-Integration
    
    # Netzwerk-Tools
    kdePackages.plasma-firewall
    kdePackages.plasma-nm
    kdePackages.kdenetwork-filesharing
    
    # Benachrichtigungen und System-Integration
    kdePackages.plasma-systemmonitor
    kdePackages.plasma-workspace
    kdePackages.knotifications
    
    # Bluetooth-Unterstützung
    kdePackages.bluedevil
    bluez
  ];

  # XDG Portal Konfiguration
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-kde
    ];
    config = {
      common = {
        default = ["kde"];
        preferred = ["kde"];
      };
      # Spezifische Portal-Konfigurationen
      kde = {
        default = ["kde"];
        "org.freedesktop.impl.portal.Secret" = ["kde"];
        "org.freedesktop.impl.portal.ScreenCast" = ["kde"];
      };
    };
  };

  # Bluetooth Hardware Support
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  # DBus und System-Services
  services = {
    # DBus Konfiguration
    dbus = {
      enable = true;
      packages = [ pkgs.kdePackages.kdeconnect-kde ];
    };
    # Avahi für Netzwerk-Discovery
    avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        userServices = true;
      };
    };
  };

  # Firewall-Regeln für KDE Connect
  networking.firewall = {
    allowedTCPPortRanges = [
      { from = 1714; to = 1764; }  # KDE Connect
    ];
    allowedUDPPortRanges = [
      { from = 1714; to = 1764; }  # KDE Connect
    ];
  };

  # Environment-Variablen
  environment.sessionVariables = {
    # Desktop-Integration
    XDG_CURRENT_DESKTOP = "KDE";
    XDG_SESSION_DESKTOP = "KDE";
    
    # KDE Connect spezifische Variablen
    KDECONNECT_ENABLE_NOTIFICATIONS = "true";
    KDECONNECT_ENABLE_CLIPBOARD = "true";
  };

  # Systemd User Service
  systemd.user.services.kdeconnect = {
    description = "KDE Connect";
    wantedBy = [ "default.target" ];
    after = [ "network.target" "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnect-indicator";
      Restart = "on-failure";
      RestartSec = "5s";
      Environment = [
        "QT_QPA_PLATFORM=wayland;xcb"
        "XDG_CURRENT_DESKTOP=KDE"
      ];
    };
  };
}