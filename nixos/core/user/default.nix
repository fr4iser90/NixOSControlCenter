{ config, pkgs, lib, systemConfig, ... }:

let
  # Gruppen basierend auf Rolle
  roleGroups = {
    admin = [ "wheel" "networkmanager" "docker" "podman" "video" "audio" "render" "input" "seat" ];
    guest = [ "networkmanager" ];
    restricted-admin = [ "wheel" "networkmanager" "video" "audio" ];
    virtualization = [ "docker" "podman" "libvirtd" "kvm" ];  # Neue Rolle für Docker/VM-User
  };

  # User-spezifische Pakete basierend auf Rolle
  rolePkgs = {
    virtualization = with pkgs; [
      docker-compose
      virt-manager
      qemu
    ];
    admin = [];  # Basis-Admin-Pakete
    guest = [];  # Basis-Guest-Pakete
  };

  # Sudo-Regeln basierend auf Rolle
  makeSudoRules = username: role: 
    if role == "admin" then [{
      users = [ username ];
      commands = [{
        command = "ALL";
        options = 
          if (systemConfig.sudo != null && systemConfig.sudo.requirePassword == true) then
            [ "PASSWD" ]
          else
            [ "NOPASSWD" ];  # Keine Passwortabfrage, wenn requirePassword nicht gesetzt oder false
      }];
    }]
    else if role == "restricted-admin" then [{
      users = [ username ];
      commands = [{
        command = "ALL";
        options = [ "PASSWD" ];  # Passwortabfrage für eingeschränkte Admins
      }];
    }]
    else [];  # Keine sudo-Rechte für andere Rollen



  # Automatisches Autologin für den ersten restricted-Admin-User
  autoLoginUser = lib.findFirst 
    (user: systemConfig.users.${user}.role == "restricted-admin" && systemConfig.users.${user}.autoLogin)
    null
    (builtins.attrNames systemConfig.users);

  # TTY-Autologin-Konfiguration
  autoLoginService = if autoLoginUser != null then {
    "getty@tty1" = {
      enable = true;
      serviceConfig = {
        ExecStart = [
          ""  # Leere den Standard-ExecStart
          "${pkgs.util-linux}/sbin/agetty --autologin ${autoLoginUser} --noclear %I $TERM"
        ];
      };
    };
  } else {};

  # Lingering-Konfiguration basierend auf Rolle
  roleLingering = {
    virtualization = true;    # Docker/VM-User brauchen Lingering
    admin = false;           # Admins normalerweise nicht
    guest = false;           # Gäste definitiv nicht
    restricted-admin = false; # Restricted Admins auch nicht
  };

in {
  imports = [ ./password-manager.nix ];
  
  # Aktiviere Passwort-Management
  security.passwordManagement.enable = true;

  # Basis-Konfiguration für alle Benutzer
  users = {
    mutableUsers = false;
    
    # Definiere Standard-Gruppen
    groups = lib.mkMerge [
      {
        users = {};
        wheel = {};
        networkmanager = {};
        docker = {};
        podman = {};
        video = {};
        audio = {};
        render = {};
        input = {};
        seat = {};
        libvirtd = {};
        kvm = {};
      }
      
      # Erstelle Gruppen für jeden Benutzer
      (lib.mapAttrs (name: _: {}) systemConfig.users)
    ];
    
    # Benutzer aus systemConfig.users erstellen
    users = lib.mapAttrs (username: userConfig: {
      isNormalUser = true;
      home = "/home/${username}";
      shell = pkgs.${userConfig.defaultShell};
      group = username;
      extraGroups = [ "users" ] ++ roleGroups.${userConfig.role};
      packages = rolePkgs.${userConfig.role} or [];
      
      # Lingering-Konfiguration
      linger = roleLingering.${userConfig.role} or false;
      
      # WICHTIG: Erst die Passwort-Konfiguration vom Manager holen
      } // (config.security.passwordManagement.getUserPasswordConfig username userConfig) // {
      
      # Dann explizit den Pfad setzen
      hashedPasswordFile = "/etc/nixos/secrets/passwords/${username}/.hashedPassword";
    }) systemConfig.users;
  };

  # Sudo-Konfiguration
  security.sudo = {
    enable = true;
    extraRules = lib.concatLists (lib.mapAttrsToList 
      (username: userConfig: makeSudoRules username userConfig.role)
      systemConfig.users
    );
  };

  # Dynamische TTY-Konfiguration
  systemd.services = autoLoginService;

  # Aktiviere die Shells auf System-Level
  programs = {
    zsh.enable = lib.any (user: systemConfig.users.${user}.defaultShell == "zsh") 
      (builtins.attrNames systemConfig.users);
    fish.enable = lib.any (user: systemConfig.users.${user}.defaultShell == "fish") 
      (builtins.attrNames systemConfig.users);
  };
}
