{ config, lib, pkgs, getModuleConfig, moduleName, systemConfig, ... }:
let
  cfg = getModuleConfig moduleName;
  userPackagesConfig = lib.attrByPath ["users"] {} systemConfig;

  # Capabilities basierend auf Rolle (für NCC Permission System)
  roleCapabilities = {
    admin = [
      "system.update" "system.build" "system.check.*" "module.*" "user.*" "package.*"
      "network.*" "hardware.*" "boot.*" "desktop.*" "audio.*" "localization.*"
    ];
    guest = [
      "system.check.self" "user.read.self"
    ];
    restricted-admin = [
      "system.update" "system.build" "system.check.*" "user.read.self" "network.read"
    ];
    virtualization = [
      "system.check.self" "user.read.self" "package.docker" "package.podman"
    ];
  };

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

  # Prüfe ob mindestens ein Admin/Restricted-Admin existiert
  hasPrivilegedUser = lib.any (user: userAttrs.${user}.role == "admin" || userAttrs.${user}.role == "restricted-admin") userNames;

  # User-spezifische Pakete aus configs/users/<name>/config.nix
  userPackages = lib.mapAttrs (name: userConfig:
    let
      packageSource = userPackagesConfig.${name} or {};
    in
      if packageSource ? userPackages && builtins.isList packageSource.userPackages
      then packageSource.userPackages
      else if userConfig ? userPackages && builtins.isList userConfig.userPackages
      then userConfig.userPackages
      else []
  ) userAttrs;
  # Convert package names to actual derivations
  resolvedUserPackages = lib.mapAttrs (name: packages:
    map (pkgName:
      if builtins.hasAttr pkgName pkgs then pkgs.${pkgName}
      else throw "Package '${pkgName}' not found in nixpkgs"
    ) packages
  ) userPackages;

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
in
{
  # Aktiviere Passwort-Management
  security.passwordManagement.enable = true;

  # Assertion: Es muss mindestens ein Admin/Restricted-Admin konfiguriert sein
  # CRITICAL: Diese Assertion feuert IMMER (auch wenn userNames leer sind).
  # Niemals ohne User bauen lassen!
  assertions = [{
    assertion = userNames != [] && hasPrivilegedUser;
    message = if userNames == [] then ''
      CRITICAL: No users configured!
      At least one user with role "admin" or "restricted-admin" must exist.
      Check system-config.nix or systemConfig/core/base/user/config.nix.
    '' else ''
      No admin or restricted-admin user configured!
      At least one user with role "admin" or "restricted-admin" is required to administer the system.
      Current users: ${builtins.toString userNames}
      Available roles: admin, restricted-admin, virtualization, guest
    '';
  }];

  # Basis-Konfiguration für alle Benutzer
  # mutableUsers = false nur wenn User konfiguriert sind,
  # sonst können User nicht per passwd angelegt werden
  users.mutableUsers = lib.mkIf (userNames != []) false;

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
    packages = (rolePkgs.${userConfig.role} or []) ++ (resolvedUserPackages.${username} or []);

    # Lingering-Konfiguration
    linger = roleLingering.${userConfig.role} or false;

    # WICHTIG: Passwort-Konfiguration vom Manager holen
    # (hashedPassword aus .hashedPassword per builtins.readFile,
    #  initialPassword nur wenn Config-Feld gesetzt)
    } // (config.security.passwordManagement.getUserPasswordConfig username userConfig)
  ) userAttrs;

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

  # NCC Permission System wird über API (api.nix) bereitgestellt

  # Aktiviere die Shells auf System-Level
  programs = {
    zsh.enable = lib.any (user: userAttrs.${user}.defaultShell == "zsh")
      userNames;
    fish.enable = lib.any (user: userAttrs.${user}.defaultShell == "fish")
      userNames;
  };
}
