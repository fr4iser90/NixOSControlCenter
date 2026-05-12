{ config, lib, pkgs, getModuleConfig, moduleName, systemConfig, ... }:
let
  cfg = getModuleConfig moduleName;

  # Per-user configs from users/<name>/config.nix
  # These merge into systemConfig.users.<name>
  perUserConfigs = lib.attrByPath ["users"] {} systemConfig;

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
    virtualization = [ "docker" "podman" "libvirtd" "kvm" ];
  };

  # Sudo-Regeln basierend auf Rolle
  makeSudoRules = username: role:
    if role == "admin" then [{
      users = [ username ];
      commands = [{
        command = "ALL";
        options = [ "NOPASSWD" ];
      }];
    }]
    else if role == "restricted-admin" then [{
      users = [ username ];
      commands = [{
        command = "ALL";
        options = [ "PASSWD" ];
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

  # Resolve per-user config for a given username
  # Returns the per-user config if available, otherwise the central config
  resolveUserConfig = username:
    if perUserConfigs ? ${username} then perUserConfigs.${username}
    else userAttrs.${username};

  # Get system-wide packages from per-user config
  # Per-user config can define: environment.systemPackages = [...]
  getUserSystemPackages = username:
    let
      userCfg = resolveUserConfig username;
      envPkgs = userCfg.environment.systemPackages or [];
    in
      if lib.isList envPkgs then envPkgs else [];

  # Get user-specific packages from per-user config
  # Per-user config can define: userPackages = ["vscode" "firefox"]
  # Falls nicht definiert: zentrale Config (userConfig.userPackages)
  getUserPackages = username:
    let
      userCfg = resolveUserConfig username;
      perUserPkgs = userCfg.userPackages or [];
      centralPkgs = if userCfg ? userPackages && builtins.isList userCfg.userPackages
                    then userCfg.userPackages
                    else [];
      # Per-user packages override central packages
      packages = if perUserPkgs != [] then perUserPkgs else centralPkgs;
    in
      packages;

  # Resolve all user packages to derivations
  resolvedUserPackages = lib.mapAttrs (name: packages:
    map (pkgName:
      let
        meta = (import ../packages/lib/metadata.nix).modules.${pkgName} or {};
      in
        if meta ? package then meta.package
        else if builtins.hasAttr pkgName pkgs then pkgs.${pkgName}
        else throw "Package '${pkgName}' not found in package metadata or nixpkgs"
    ) packages
  ) (lib.mapAttrs (name: _: getUserPackages name) userAttrs);

  # Resolve system packages from per-user configs
  # These go into environment.systemPackages (user-scoped, not global)
  resolvedUserSystemPackages = lib.mapAttrs (name: packages:
    map (pkgName:
      if builtins.hasAttr pkgName pkgs then pkgs.${pkgName}
      else throw "Package '${pkgName}' not found in nixpkgs"
    ) packages
  ) (lib.mapAttrs (name: _: getUserSystemPackages name) userAttrs);

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
          ""
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

  # Merge system overrides from per-user configs
  # Per-user config can define: networking.*, services.*, security.*, etc.
  userSystemOverrides = lib.mapAttrs (name: userCfg:
    let
      # Extract system-level overrides
      networking = userCfg.networking or {};
      services = userCfg.services or {};
      security = userCfg.security or {};
      environment = userCfg.environment or {};
      systemd = userCfg.systemd or {};
      programs = userCfg.programs or {};
    in
      {
        inherit networking services security environment systemd programs;
      }
  ) perUserConfigs;

  # Collect all system overrides for each user
  # (Currently just for documentation — actual merging happens via separate modules)
  allUserOverrides = if userNames != [] then userSystemOverrides.${(builtins.head userNames)} or {} else {};
in
{
  # Aktiviere Passwort-Management
  security.passwordManagement.enable = true;

  # Assertion: Es muss mindestens ein Admin/Restricted-Admin konfiguriert sein
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

    (lib.mapAttrs (name: _: {}) userAttrs)
  ];

  # Benutzer erstellen — mit Unterstützung für per-user configs
  users.users = lib.mapAttrs (username: userConfig: {
    isNormalUser = true;
    home = "/home/${username}";
    shell = pkgs.${userConfig.defaultShell};
    group = username;
    extraGroups = [ "users" ] ++ roleGroups.${userConfig.role};
    # Combine central role packages + per-user system packages + resolved user packages
    packages = (resolvedUserPackages.${username} or []);

    linger = roleLingering.${userConfig.role} or false;

  } // (config.security.passwordManagement.getUserPasswordConfig username userConfig)) userAttrs;

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

  # NCC Permission System wird über API (api.nix) bereitgestellt
}
