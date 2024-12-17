{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  # Alle Profile in einem Ordner
  profiles = {
    # Desktop Profiles
    "gaming-workstation" = ./profiles/gaming-workstation.nix;
    "workstation" = ./profiles/workstation.nix;
    "minimal-desktop" = ./profiles/minimal-desktop.nix;
    
    # Server Profiles
    "dns-server" = ./profiles/dns-server.nix;
    "media-server" = ./profiles/media-server.nix;
    "headless-server" = ./profiles/headless-server.nix;
    "web-server" = ./profiles/web-server.nix;
    
    # Hybrid Profiles
    "dev-workstation" = ./profiles/dev-workstation.nix;
  };

in {
  imports = [
    (if profiles ? ${systemConfig.systemType}
     then profiles.${systemConfig.systemType}
     else throw "Unknown system type: ${systemConfig.systemType}. Valid types: ${toString (attrNames profiles)}")
  ];

  # Gemeinsame Basis-Konfiguration
  i18n = {
    defaultLocale = "en_US.UTF-8";
    supportedLocales = [
      "de_DE.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
    ];
  };
}