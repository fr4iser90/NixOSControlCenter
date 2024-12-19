# modules/system-management/preflight/checks/system/users.nix
{ config, lib, pkgs, systemConfig, ... }:

let
  preflightScript = pkgs.writeScriptBin "preflight-check-users" ''
    #!${pkgs.bash}/bin/bash
    set -e
    
    echo "Checking user configuration..."
    
    # Aktuelle System-Benutzer ermitteln, aber nixbld* und andere System-Benutzer ausschließen
    CURRENT_USERS=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 && $1 !~ /^nixbld/ && $1 !~ /^systemd-/ {print $1}')
    
    # Konfigurierte Benutzer aus system-config
    CONFIGURED_USERS="${builtins.concatStringsSep " " (builtins.attrNames systemConfig.users)}"
    
    # Passwort-Verzeichnis
    PASSWORD_DIR="/etc/nixos/secrets/passwords"
    
    echo "Current system users: $CURRENT_USERS"
    echo "Configured users: $CONFIGURED_USERS"
    
    # Vergleich durchführen
    changes_detected=0
    removed_users=""
    added_users=""
    users_without_password=""
    
    # Prüfe auf Änderungen und fehlende Passwörter
    for user in $CONFIGURED_USERS; do
      # Prüfe ob Benutzer neu ist
      if ! echo "$CURRENT_USERS" | grep -q "$user"; then
        added_users="$added_users $user"
        changes_detected=1
      fi
      
      # Prüfe ob Passwort existiert
      if [ ! -f "$PASSWORD_DIR/$user/.hashedPassword" ] || [ ! -s "$PASSWORD_DIR/$user/.hashedPassword" ]; then
        users_without_password="$users_without_password $user"
      fi
    done
    
    # Prüfe auf zu entfernende Benutzer
    for user in $CURRENT_USERS; do
      if ! echo "$CONFIGURED_USERS" | grep -q "$user"; then
        removed_users="$removed_users $user"
        changes_detected=1
      fi
    done
    
    # Zeige Änderungen an
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
    fi
    
    # Passwort-Management
    if [ ! -z "$users_without_password" ]; then
      echo "⚠️  The following users have no password set:$users_without_password"
      
      for user in $users_without_password; do
        while true; do
          echo ""
          echo "Setting password for user: $user"
          read -p "Do you want to set a password for $user now? [Y/n/s(skip)] " response
          
          case $response in
            [Nn]* )
              echo "Aborting system rebuild."
              exit 1
              ;;
            [Ss]* )
              echo "Skipping password for $user"
              break
              ;;
            * )
              # Erstelle Passwort-Verzeichnis
              sudo mkdir -p "$PASSWORD_DIR/$user"
              sudo chown $user:users "$PASSWORD_DIR/$user"
              sudo chmod 700 "$PASSWORD_DIR/$user"
              
              # Setze Passwort
              if passwd $user; then
                # Speichere gehashtes Passwort (korrigierte Version)
                sudo sh -c "getent shadow $user | cut -d: -f2 > $PASSWORD_DIR/$user/.hashedPassword"
                sudo chown $user:users "$PASSWORD_DIR/$user/.hashedPassword"
                sudo chmod 600 "$PASSWORD_DIR/$user/.hashedPassword"
                echo "✅ Password set successfully for $user"
                break
              else
                echo "❌ Failed to set password, please try again"
              fi
              ;;
          esac
        done
      done
    fi
    
    if [ $changes_detected -eq 1 ]; then
      read -p "Continue with system rebuild? [y/N] " response
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