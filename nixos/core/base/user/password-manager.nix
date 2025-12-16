{ config, lib, pkgs, ... }:

let
  getUserPasswordConfig = username: userConfig:
    let
      passwordDir = "/etc/nixos/secrets/passwords";
      userPasswordFile = "${passwordDir}/${username}/.hashedPassword";
    in {
      # Nur die Passwortdatei nutzen, wenn sie existiert
      hashedPasswordFile = lib.mkIf (builtins.pathExists userPasswordFile) 
        userPasswordFile;
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

  config = lib.mkIf config.security.passwordManagement.enable {
    # Erlaube temporär Logins während des Builds
    users.allowNoPasswordLogin = lib.mkForce true;
    
    # Erlaube mutable Users nur wenn keine Passwortdatei existiert
    users.mutableUsers = lib.mkDefault (lib.mkIf (builtins.length (builtins.attrNames realUsers) == 0) true);
    
    system.activationScripts.passwordSetup = {
      text = ''
      # Hauptverzeichnis
      mkdir -p /etc/nixos/secrets/passwords
      chmod 700 /etc/nixos/secrets/passwords
      chown root:root /etc/nixos/secrets/passwords
      
      # Liste der erlaubten Benutzer
      ALLOWED_USERS="${lib.concatStringsSep " " (builtins.attrNames realUsers)}"
      
      # Lösche nicht benötigte Verzeichnisse
      for dir in /etc/nixos/secrets/passwords/*; do
        basename=$(basename "$dir")
        if [[ ! " $ALLOWED_USERS " =~ " $basename " ]]; then
          echo "Removing unauthorized password directory: $dir"
          rm -rf "$dir"
        fi
      done
      
      # Benutzerverzeichnisse: Nur Berechtigungen setzen
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (username: userConfig: ''
        if [ -f /etc/nixos/secrets/passwords/${username}/.hashedPassword ]; then
          chmod 600 /etc/nixos/secrets/passwords/${username}/.hashedPassword
          chown ${username}:${username} /etc/nixos/secrets/passwords/${username}/.hashedPassword
        fi
      '') realUsers)}
    '';
      deps = [];
    };
  };
}