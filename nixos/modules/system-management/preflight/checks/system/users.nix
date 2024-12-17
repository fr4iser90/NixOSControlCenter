# modules/system-management/preflight/checks/system/users.nix
{ config, lib, pkgs, systemConfig, ... }:

let
  preflightScript = pkgs.writeScriptBin "check-users" ''
    #!${pkgs.bash}/bin/bash
    set -e
    
    echo "Checking user configuration..."
    
    # Aktuelle System-Benutzer ermitteln
    CURRENT_USERS=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}')
    
    # Konfigurierte Benutzer aus system-config
    CONFIGURED_USERS="${builtins.concatStringsSep " " (builtins.attrNames systemConfig.users)}"
    
    echo "Current system users: $CURRENT_USERS"
    echo "Configured users: $CONFIGURED_USERS"
    
    # Vergleich durchführen
    changes_detected=0
    removed_users=""
    added_users=""
    
    # Prüfe auf Änderungen
    for user in $CURRENT_USERS; do
      if ! echo "$CONFIGURED_USERS" | grep -q "$user"; then
        removed_users="$removed_users $user"
        changes_detected=1
      fi
    done
    
    for user in $CONFIGURED_USERS; do
      if ! echo "$CURRENT_USERS" | grep -q "$user"; then
        added_users="$added_users $user"
        changes_detected=1
      fi
    done
    
    if [ $changes_detected -eq 1 ]; then
      echo "⚠️  WARNING: User configuration changes detected!"
      
      if [ ! -z "$removed_users" ]; then
        echo "Users to be removed:$removed_users"
      fi
      
      if [ ! -z "$added_users" ]; then
        echo "Users to be added:$added_users"
      fi
      
      echo "⚠️  You will need to log out and log back in after applying these changes!"
      echo "⚠️  Make sure to save all your work before proceeding!"
      
      read -p "Continue anyway? [y/N] " response
      if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Aborting system rebuild."
        exit 1
      fi
    fi
    
    echo "✅ User configuration check passed"
    exit 0
  '';

in {
  config = {
    environment.systemPackages = [ preflightScript ];
  };
}