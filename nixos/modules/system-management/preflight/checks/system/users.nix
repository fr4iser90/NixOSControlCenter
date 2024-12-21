# modules/system-management/preflight/checks/system/users.nix
{ config, lib, pkgs, systemConfig, reportingConfig, ... }:

let
  preflightScript = pkgs.writeScriptBin "preflight-check-users" ''
    #!${pkgs.bash}/bin/bash
    set -e
    
    ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.standard then ''
      ${reportingConfig.formatting.section "User Configuration Check"}
    '' else ""}
    
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
            ${reportingConfig.formatting.warning "Cannot check passwords (no root access)"}
            return 0
        fi

        for user in "''${users[@]}"; do
            if ! echo "$shadow_content" | grep -q "^$user:[^\*\!:]"; then
                if [ ! -f "/etc/nixos/secrets/passwords/$user/.hashedPassword" ] || [ ! -s "/etc/nixos/secrets/passwords/$user/.hashedPassword" ]; then
                    no_password+=("$user")
                fi
            fi
        done

        if [ ''${#no_password[@]} -gt 0 ]; then
            missing_users=$(printf '%s ' "''${no_password[@]}")
            ${reportingConfig.formatting.warning "The following users have no password set:"} 
            ${reportingConfig.formatting.warning "$missing_users"}
            return 1
        fi

        return 0
    }

    # Get current and configured users
    CURRENT_USERS=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 && $1 !~ /^nixbld/ && $1 !~ /^systemd-/ {print $1}')
    SYSTEMD_USERS=$(loginctl list-users | awk 'NR>1 {print $2}' | grep -v '^users$')
    CONFIGURED_USERS="${builtins.concatStringsSep " " (builtins.attrNames systemConfig.users)}"
    PASSWORD_DIR="/etc/nixos/secrets/passwords"
    
    ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.detailed then ''
      ${reportingConfig.formatting.keyValue "Current system users" "$CURRENT_USERS"}
      ${reportingConfig.formatting.keyValue "Current systemd users" "$SYSTEMD_USERS"}
      ${reportingConfig.formatting.keyValue "Configured users" "$CONFIGURED_USERS"}
    '' else ""}
    
    # Track changes
    changes_detected=0
    removed_users=""
    added_users=""
    users_without_password=""
    
    # Check for users to be removed
    for user in $CURRENT_USERS $SYSTEMD_USERS; do
      if ! echo "$CONFIGURED_USERS" | grep -q "$user"; then
        ${reportingConfig.formatting.warning "User '$user' will be removed by NixOS"}
        
        ${if reportingConfig.currentLevel >= reportingConfig.reportLevels.standard then ''
          ${reportingConfig.formatting.info "Cleaning up systemd for $user..."}
        '' else ""}
        
        # Get user ID
        USER_ID=$(id -u "$user" 2>/dev/null || getent passwd "$user" | cut -d: -f3 || echo "")
        
        if [ ! -z "$USER_ID" ]; then
          # Cleanup actions
          sudo loginctl disable-linger "$user" 2>/dev/null || true
          sudo pkill -u "$USER_ID" 2>/dev/null || true
          for session in $(loginctl list-sessions --no-legend | awk "\$2 == $USER_ID {print \$1}"); do
            sudo loginctl terminate-session "$session" 2>/dev/null || true
          done
          sudo rm -rf "/run/user/$USER_ID" 2>/dev/null || true
        fi
        
        # Force systemd reload
        if command -v dbus-launch >/dev/null 2>&1; then
          dbus-launch --exit-with-session sudo systemctl daemon-reload || true
        else
          sudo systemctl daemon-reload || true
        fi
        
        removed_users="$removed_users $user"
        changes_detected=1
      fi
    done
    
    # Check for new users
    for user in $CONFIGURED_USERS; do
      if ! echo "$CURRENT_USERS" | grep -q "$user"; then
        added_users="$added_users $user"
        changes_detected=1
        
        if [ ! -f "$PASSWORD_DIR/$user/.hashedPassword" ] || [ ! -s "$PASSWORD_DIR/$user/.hashedPassword" ]; then
          users_without_password="$users_without_password $user"
        fi
      fi
    done
    
    # Show changes
    if [ $changes_detected -eq 1 ]; then
      ${reportingConfig.formatting.warning "User configuration changes detected!"}
      
      if [ ! -z "$removed_users" ]; then
        ${reportingConfig.formatting.keyValue "Users removed" "$removed_users"}
      fi
      
      if [ ! -z "$added_users" ]; then
        ${reportingConfig.formatting.keyValue "Users to be added" "$added_users"}
      fi
      
      # Password Management
      if [ ! -z "$users_without_password" ]; then
        ${reportingConfig.formatting.warning "Users without password:$users_without_password"}
        
        for user in $users_without_password; do
          while true; do
            echo ""
            ${reportingConfig.formatting.info "Setting password for user: $user"}
            read -p "Do you want to set a password for $user now? [Y/n/s(skip)] " response
            
            case $response in
              [Nn]* )
                ${reportingConfig.formatting.error "Aborting system rebuild."}
                exit 1
                ;;
              [Ss]* )
                ${reportingConfig.formatting.info "Skipping password for $user"}
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
                  ${reportingConfig.formatting.success "Password set successfully for $user"}
                  break
                else
                  ${reportingConfig.formatting.error "Failed to set password, please try again"}
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
        ${reportingConfig.formatting.error "Aborting system rebuild."}
        exit 1
      fi
    fi
    
    ${reportingConfig.formatting.success "User configuration check passed"}
    exit 0
  '';

in {
  config = {
    environment.systemPackages = [ preflightScript ];
  };
}