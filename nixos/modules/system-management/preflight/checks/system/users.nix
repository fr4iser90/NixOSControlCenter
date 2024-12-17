# modules/system-management/preflight/checks/system/users.nix
{ config, lib, pkgs, systemConfig, ... }:

let
  inherit (lib) types;
  inherit (pkgs) writeScript;

  # Hilfsfunktion zum Vergleich der Benutzer
  getUsersFromPasswd = writeScript "get-users" ''
    getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}'
  '';

  # Aktuelle Benutzer aus system-config.nix
  configuredUsers = builtins.attrNames systemConfig.users;

  # Check-Funktion
  checkUsers = {
    name = "user-consistency";
    description = "Checking for user configuration changes";
    check = ''
      # Aktuelle System-Benutzer ermitteln
      current_users=$(${getUsersFromPasswd})
      
      # Konfigurierte Benutzer aus system-config
      configured_users="${builtins.concatStringsSep " " configuredUsers}"
      
      # Vergleich durchführen
      changes_detected=0
      removed_users=""
      added_users=""
      
      # Prüfe auf zu entfernende Benutzer
      for user in $current_users; do
        if ! echo "$configured_users" | grep -q "$user"; then
          removed_users="$removed_users $user"
          changes_detected=1
        fi
      done
      
      # Prüfe auf neue Benutzer
      for user in $configured_users; do
        if ! echo "$current_users" | grep -q "$user"; then
          added_users="$added_users $user"
          changes_detected=1
        fi
      done
      
      # Ausgabe der Änderungen
      if [ $changes_detected -eq 1 ]; then
        echo "⚠️  CAUTION: User changes detected!"
        
        if [ ! -z "$removed_users" ]; then
          echo "   Users to be removed:$removed_users"
        fi
        
        if [ ! -z "$added_users" ]; then
          echo "   Users to be added:$added_users"
        fi
        
        echo "   ⚠️  You will need to log out and log back in after applying these changes!"
        echo "   ⚠️  Make sure to save all your work before proceeding!"
        
        # Exit mit Warnung (aber nicht Fehler)
        exit 2
      fi
      
      echo "✅ User configuration is consistent"
      exit 0
    '';
  };

in {
  config = {
    system.checks.preflight = [ checkUsers ];
  };
}