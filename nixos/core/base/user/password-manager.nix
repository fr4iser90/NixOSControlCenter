{ config, lib, pkgs, ... }:

let
  getUserPasswordConfig = username: userConfig:
    let
      passwordDir = "/etc/nixos/secrets/passwords";
      userPasswordFile = "${passwordDir}/${username}/.hashedPassword";
      hasPasswordFile = builtins.pathExists userPasswordFile;
    in {
      # Wenn .hashedPassword existiert: deklarativ setzen
      hashedPasswordFile = lib.mkIf hasPasswordFile userPasswordFile;

      # Wenn kein .hashedPassword aber initialPassword im Config:
      # NixOS setzt es beim ersten Boot (via /etc/.initial-password-<user> Flag)
      initialPassword = lib.mkIf (!hasPasswordFile && userConfig ? initialPassword)
        userConfig.initialPassword;
    };

  # Nur echte Benutzer (keine System-Accounts)
  realUsers = lib.filterAttrs (name: user: 
    user.isNormalUser or false && 
    !(lib.hasPrefix "nixbld" name) &&
    !(lib.elem name [
      "messagebus" "nobody" "nscd" "polkituser" "root" "sddm"
      "systemd-coredump" "systemd-network" "systemd-resolve"
      "systemd-timesync" "systemd-oom" "nm-iodine" "nm-openvpn"
      "rtkit"
    ])
  ) config.users.users;

in {
  options = {
    security.passwordManagement = {
      enable = lib.mkEnableOption "password management";
      getUserPasswordConfig = lib.mkOption {
        internal = true;
        default = getUserPasswordConfig;
      };
    };
  };

  config = {
    # Erlaube temporär Logins während des Builds
    users.allowNoPasswordLogin = lib.mkForce true;
    
    # Erlaube mutable Users nur wenn keine Passwortdatei existiert
    users.mutableUsers = lib.mkIf (builtins.length (builtins.attrNames realUsers) == 0) true;
    
    system.activationScripts.passwordSetup = {
      text = ''
      # Hauptverzeichnis
      mkdir -p /etc/nixos/secrets/passwords
      chmod 700 /etc/nixos/secrets/passwords
      chown root:root /etc/nixos/secrets/passwords
      
      # AUFRAUMUNG: Nur warnen, NIEMALS loeschen!
      # Passwort-Ordner werden nie geloescht, da selbst ein kurzzeitiger
      # Config-Fehler sonst alle Passwoerter unwiderruflich vernichten wuerde.
      ALLOWED_USERS="${lib.concatStringsSep " " (builtins.attrNames realUsers)}"
      
      for dir in /etc/nixos/secrets/passwords/*; do
        [ -e "$dir" ] || continue
        basename=$(basename "$dir")
        if [ -n "$ALLOWED_USERS" ] && [[ ! " $ALLOWED_USERS " =~ " $basename " ]]; then
          echo "WARNING: Orphaned password directory for '$basename' (not in current user config)"
        fi
      done
      
      # Berechtigungen fuer konfigurierte User setzen
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (username: userConfig: ''
        if [ -f /etc/nixos/secrets/passwords/${username}/.hashedPassword ]; then
          chmod 600 /etc/nixos/secrets/passwords/${username}/.hashedPassword
          chown root:root /etc/nixos/secrets/passwords/${username}/.hashedPassword
        fi
      '') realUsers)}
    '';
      deps = [ "users" ];
    };
  };
}