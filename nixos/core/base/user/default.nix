{ config, pkgs, lib, systemConfig, getModuleConfig, ... }:

let
  cfg = getModuleConfig "user";

  # Gruppen basierend auf Rolle
  roleGroups = {
    admin = [ "wheel" "networkmanager" "docker" "podman" "video" "audio" "render" "input" "seat" ];
    guest = [ "networkmanager" ];
    restricted-admin = [ "wheel" "networkmanager" "video" "audio" ];
    virtualization = [ "docker" "podman" "libvirtd" "kvm" ];  # Neue Rolle für Docker/VM-User
  };

  # User-spezifische Pakete basierend auf Rolle
  # NOTE: Docker, QEMU, virt-manager etc. werden von Features installiert!
  # User-Rollen geben nur Berechtigungen (Gruppen, Sudo), keine Pakete!
  rolePkgs = {
    virtualization = [];  # Pakete kommen von docker.nix, qemu-vm.nix, virt-manager.nix Features
    admin = [];  # Basis-Admin-Pakete
    guest = [];  # Basis-Guest-Pakete
  };

  # Sudo-Regeln basierend auf Rolle
  makeSudoRules = username: role: 
    if role == "admin" then [{
      users = [ username ];
      commands = [{
        command = "ALL";
        options = [ "NOPASSWD" ];  # Keine Passwortabfrage für Admin
      }];
    }]
    else if role == "restricted-admin" then [{
      users = [ username ];
      commands = [{
        command = "ALL";
        options = [ "PASSWD" ];  # Passwortabfrage für eingeschränkte Admins
      }];
    }]
    else if role == "virtualization" then [{
      users = [ username ];
      commands = [
        { command = "/run/current-system/sw/bin/docker swarm *"; options = [ "NOPASSWD" ]; }
        { command = "/run/current-system/sw/bin/docker node *"; options = [ "NOPASSWD" ]; }
      ];
    }]
    else [];

  # Filter out non-user attributes (like 'enable')
  userAttrs = lib.filterAttrs (n: v: builtins.isAttrs v) cfg;
  userNames = builtins.attrNames userAttrs;

  # Automatisches Autologin für den ersten restricted-Admin-User
  autoLoginUser = lib.findFirst
    (user: userAttrs.${user}.role == "restricted-admin" && userAttrs.${user}.autoLogin)
    null
    userNames;

  hasVirtualizationUser = lib.any (user: userAttrs.${user}.role == "virtualization")
    userNames;
    
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
    virtualization = true;
    admin = false;           
    guest = false;           
    restricted-admin = false; 
  };

in {
  _module.metadata = {
    role = "internal";
    name = "user";
    description = "User account management and configuration";
    category = "base";
    subcategory = "user";
    stability = "stable";
  };

  imports = [
    ./options.nix
    ./config.nix
    ./password-manager.nix
  ];
  
  # Aktiviere Passwort-Management
  security.passwordManagement.enable = true;

  # Basis-Konfiguration für alle Benutzer
  users.mutableUsers = false;

  # Definiere Standard-Gruppen
  users.groups = lib.mkMerge [
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
    (lib.mapAttrs (name: _: {}) userAttrs)
  ];

  # Benutzer aus gefilterten userAttrs erstellen
  users.users = lib.mapAttrs (username: userConfig: {
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
  }) userAttrs;

  # Sudo-Konfiguration
  security.sudo = {
    enable = true;
    extraRules = lib.concatLists (lib.mapAttrsToList
      (username: userConfig: makeSudoRules username userConfig.role)
      userAttrs
    );
  };

  # Dynamische TTY-Konfiguration
  systemd.services = autoLoginService;
  
  # Aktiviere die Shells auf System-Level
  programs = {
    zsh.enable = lib.any (user: userAttrs.${user}.defaultShell == "zsh")
      userNames;
    fish.enable = lib.any (user: userAttrs.${user}.defaultShell == "fish")
      userNames;
  };
}
