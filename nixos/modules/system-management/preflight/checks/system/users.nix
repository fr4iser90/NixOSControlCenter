# modules/system-management/preflight/checks/system/users.nix
{ config, lib, pkgs, systemConfig, ... }:

let
  preflightScript = pkgs.writeScriptBin "preflight-check-users" ''
    #!${pkgs.bash}/bin/bash
    set -e
    
    # Color definitions
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
    
    echo "Checking user configuration..."
    
    # Password checking function
    check_passwords() {
        local users=("$@")
        local no_password=()

        # Prüfe zuerst /etc/shadow für existierende Passwörter
        if [ "$(id -u)" -eq 0 ]; then
            shadow_content=$(cat /etc/shadow)
        else
            shadow_content=$(sudo cat /etc/shadow 2>/dev/null || echo "")
        fi

        if [ -z "$shadow_content" ]; then
            echo -e "''${YELLOW}⚠️  Cannot check passwords (no root access)''${NC}"
            return 0
        fi

        for user in "''${users[@]}"; do
            # Prüfe erst shadow, dann das Passwort-Verzeichnis
            if ! echo "$shadow_content" | grep -q "^$user:[^\*\!:]"; then
                if [ ! -f "/etc/nixos/secrets/passwords/$user/.hashedPassword" ] || [ ! -s "/etc/nixos/secrets/passwords/$user/.hashedPassword" ]; then
                    no_password+=("$user")
                fi
            fi
        done

        if [ ''${#no_password[@]} -gt 0 ]; then
            echo -e "''${YELLOW}⚠️  The following users have no password set: ''${no_password[*]}''${NC}"
            return 1
        fi

        return 0
    }

    # Get current and configured users
    CURRENT_USERS=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 && $1 !~ /^nixbld/ && $1 !~ /^systemd-/ {print $1}')
    SYSTEMD_USERS=$(loginctl list-users | awk 'NR>1 {print $2}' | grep -v '^users$')
    CONFIGURED_USERS="${builtins.concatStringsSep " " (builtins.attrNames systemConfig.users)}"
    PASSWORD_DIR="/etc/nixos/secrets/passwords"
    
    echo "Current system users: $CURRENT_USERS"
    echo "Current systemd users: $SYSTEMD_USERS"
    echo "Configured users: $CONFIGURED_USERS"
    
    # Track changes
    changes_detected=0
    removed_users=""
    added_users=""
    users_without_password=""
    
    # Check for users to be removed (both from passwd and systemd)
    for user in $CURRENT_USERS $SYSTEMD_USERS; do
      if ! echo "$CONFIGURED_USERS" | grep -q "$user"; then
        echo -e "''${YELLOW}Notice: User '$user' will be removed by NixOS''${NC}"
        
        # Aggressivere Cleanup von systemd
        echo "Cleaning up systemd for $user..."
        
        # Get user ID (falls der User noch existiert)
        USER_ID=$(id -u "$user" 2>/dev/null || getent passwd "$user" | cut -d: -f3 || echo "")
        
        if [ ! -z "$USER_ID" ]; then
          # Disable lingering
          sudo loginctl disable-linger "$user" 2>/dev/null || true
          
          # Kill all user processes
          sudo pkill -u "$USER_ID" 2>/dev/null || true
          
          # Force terminate all sessions
          for session in $(loginctl list-sessions --no-legend | awk "\$2 == $USER_ID {print \$1}"); do
            sudo loginctl terminate-session "$session" 2>/dev/null || true
          done
          
          # Remove user runtime directory
          sudo rm -rf "/run/user/$USER_ID" 2>/dev/null || true
        fi
        
        # Force systemd to reload its configuration
        if command -v dbus-launch >/dev/null 2>&1; then
          dbus-launch --exit-with-session sudo systemctl daemon-reload || true
        else
          sudo systemctl daemon-reload || true
        fi
        
        removed_users="$removed_users $user"
        changes_detected=1
      fi
    done
    
    # Check for new users and password status
    for user in $CONFIGURED_USERS; do
      # Check if user is new
      if ! echo "$CURRENT_USERS" | grep -q "$user"; then
        added_users="$added_users $user"
        changes_detected=1
        
        # Only check password for new users or existing configured users
        if [ ! -f "$PASSWORD_DIR/$user/.hashedPassword" ] || [ ! -s "$PASSWORD_DIR/$user/.hashedPassword" ]; then
          users_without_password="$users_without_password $user"
        fi
      fi
    done
    
    # Show changes
    if [ $changes_detected -eq 1 ]; then
      echo -e "''${YELLOW}⚠️  User configuration changes detected!''${NC}"
      
      if [ ! -z "$removed_users" ]; then
        echo "Users removed:$removed_users"
      fi
      
      if [ ! -z "$added_users" ]; then
        echo "Users to be added:$added_users"
      fi
      
      # Password Management - nur für neue oder konfigurierte User
      if [ ! -z "$users_without_password" ]; then
        echo -e "''${YELLOW}⚠️  Users without password:$users_without_password''${NC}"
        
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
                # Create password directory
                sudo mkdir -p "$PASSWORD_DIR/$user"
                sudo chown $user:users "$PASSWORD_DIR/$user"
                sudo chmod 700 "$PASSWORD_DIR/$user"
                
                # Set password
                if passwd $user; then
                  sudo sh -c "getent shadow $user | cut -d: -f2 > $PASSWORD_DIR/$user/.hashedPassword"
                  sudo chown $user:users "$PASSWORD_DIR/$user/.hashedPassword"
                  sudo chmod 600 "$PASSWORD_DIR/$user/.hashedPassword"
                  echo -e "''${GREEN}✅ Password set successfully for $user''${NC}"
                  break
                else
                  echo -e "''${RED}❌ Failed to set password, please try again''${NC}"
                fi
                ;;
            esac
          done
        done
      fi
    fi
    
    # Confirm changes
    if [ $changes_detected -eq 1 ]; then
      read -p "Continue with system rebuild? [y/N] " response
      if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Aborting system rebuild."
        exit 1
      fi
    fi
    
    echo -e "''${GREEN}✅ User configuration check passed''${NC}"
    exit 0
  '';

in {
  config = {
    environment.systemPackages = [ preflightScript ];
  };
}