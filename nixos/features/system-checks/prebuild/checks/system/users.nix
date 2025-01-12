{ config, lib, pkgs, systemConfig, ... }:

let
  ui = config.features.terminal-ui.api;
  
  prebuildScript = pkgs.writeScriptBin "prebuild-check-users" ''
    #!${pkgs.bash}/bin/bash
    set -e
    
    ${ui.text.header "User Configuration Check"}
    
    # Get current and configured users (mit Filter für echte User)
    CURRENT_USERS=`getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 && $1 !~ /^nixbld/ {print $1}'`
    CONFIGURED_USERS="${builtins.concatStringsSep " " (builtins.attrNames systemConfig.users)}"

    ${ui.tables.keyValue "Current users" "$CURRENT_USERS"}
    ${ui.tables.keyValue "Configured users" "$CONFIGURED_USERS"}

    # Initialize tracking
    changes_detected=0
    removed_users=""
    added_users=""
    users_without_password=""

    # Check for users that will be removed
    for user in $CURRENT_USERS; do
      if ! echo "$CONFIGURED_USERS" | grep -q "$user"; then
        ${ui.badges.warning "User '$user' will be removed"}
        removed_users="$removed_users $user"
        changes_detected=1
      fi
    done

    # Check for new users
    for user in $CONFIGURED_USERS; do
      if ! echo "$CURRENT_USERS" | grep -q "$user"; then
        ${ui.badges.info "User '$user' will be added"}
        added_users="$added_users $user"
        changes_detected=1
      fi
    done

    # Show summary if changes detected
    if [ $changes_detected -eq 1 ]; then
      ${ui.badges.warning "User changes detected!"}
      
      if [ ! -z "$removed_users" ]; then
        ${ui.tables.keyValue "Users to remove" "$removed_users"}
      fi
      
      if [ ! -z "$added_users" ]; then
        ${ui.tables.keyValue "Users to add" "$added_users"}
      fi

      # Ask for confirmation
      read -p "Continue with these changes? [y/N] " response
      if [[ ! "$response" =~ ^[Yy]$ ]]; then
        ${ui.badges.error "Aborting."}
        exit 1
      fi
    fi

    ${ui.badges.success "User check complete"}
    exit 0
  '';

in {
  config = {
    environment.systemPackages = [ prebuildScript ];
    features.command-center.commands.userCheck = {
      name = "check-users";
      category = "system-checks";
      description = "Check user configuration before system rebuild";
      script = prebuildScript;
      shortHelp = "check-users - Verify user configuration";
      longHelp = ''
        Check user configuration before system rebuild
        
        Checks:
        - Current vs configured users
        - User passwords
        - Password directories
        - System cleanup for removed users
        
        Interactive: Yes (for password management)
      '';
      interactive = true;
      dependencies = [ "system-checks" ];
    };
  };
}