{ config, pkgs, lib, ... }:

let
  env = import ../../env.nix;

  # Gruppen basierend auf Rolle
  roleGroups = {
    admin = [ "wheel" "networkmanager" "docker" "video" "audio" "render" "input" ];
    guest = [ "networkmanager" ];
    "restricted-admin" = [ "wheel" "networkmanager" "video" "audio" ];
  };

  # Sudo-Regeln basierend auf Rolle
  makeSudoRules = username: role: 
    if role == "admin" then [{
      users = [ username ];
      commands = [{
        command = "ALL";
        options = if env.sudo.requirePassword or true
          then [ "PASSWD" ]
          else [ "NOPASSWD" ];
      }];
    }]
    else if role == "restricted-admin" then [{
      users = [ username ];
      commands = [{
        command = "ALL";
        options = [ "PASSWD" ];
      }];
    }]
    else [];  # Keine sudo-Rechte für andere Rollen

in {
  # Basis-Konfiguration für alle Benutzer
  users.mutableUsers = false;

  # Aktiviere die Shells auf System-Level
  programs = {
    zsh.enable = lib.any (user: env.users.${user}.defaultShell == "zsh") (builtins.attrNames env.users);
    fish.enable = lib.any (user: env.users.${user}.defaultShell == "fish") (builtins.attrNames env.users);
  };
  
  # Benutzer aus env.users erstellen
  users.users = lib.mapAttrs (username: userConfig: {
    isNormalUser = true;
    home = "/home/${username}";
    shell = pkgs.${userConfig.defaultShell};
    hashedPasswordFile = if userConfig.role == "admin" 
      then "/etc/nixos/secrets/passwords/.hashedLoginPassword"
      else null;
    extraGroups = roleGroups.${userConfig.role};
  }) env.users;

  # Sudo-Konfiguration
  security.sudo = {
    enable = true;
    extraRules = lib.concatLists (lib.mapAttrsToList 
      (username: userConfig: makeSudoRules username userConfig.role)
      env.users
    );
    
    extraConfig = ''
      Defaults secure_path="/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/run/current-system/sw/bin:/run/current-system/sw/sbin"
      Defaults env_keep += "NIX_PATH NIX_PROFILES NIX_REMOTE NIX_SSL_CERT_FILE"
      Defaults timestamp_timeout=${toString (env.sudo.timeout or 15)}
      Defaults lecture=once
    '';
  };

  # TTY-Konfiguration
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;
}