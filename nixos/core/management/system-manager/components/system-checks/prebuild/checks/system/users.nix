{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

let
  cliRegistry = getModuleApi "cli-registry";
  # GENERISCH: CLI Formatter API über getModuleApi beziehen
  ui = getModuleApi "cli-formatter"; 
  
  prebuildScript = pkgs.writeScriptBin "prebuild-check-users" ''
    #!${pkgs.bash}/bin/bash
    set -e
    
    ${ui.text.header "User Configuration Check"}
    
    # Get current and configured users (mit Filter für echte User)
    CURRENT_USERS=`getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 && $1 !~ /^nixbld/ {print $1}'`
    CONFIGURED_USERS="${builtins.concatStringsSep " " (builtins.attrNames (lib.filterAttrs (n: v: builtins.isAttrs v) (getModuleConfig "user")))}"
    ${ui.tables.keyValue "Current users" "$CURRENT_USERS"}
    ${ui.tables.keyValue "Configured users" "$CONFIGURED_USERS"}

    # CRITICAL: Runtime-Prüfung der User-Config-Datei (unabhängig von Nix-Evaluation)
    # Die CONFIGURED_USERS oben wird bei der letzten Nix-Evaluation hardcoded.
    # Wenn die Config-Datei seitdem geändert wurde, müssen wir hier runtime checken.
    USER_CONFIG_FILE="/etc/nixos/systemConfig/core/base/user/config.nix"
    if [ ! -f "$USER_CONFIG_FILE" ]; then
      ${ui.badges.error "CRITICAL: User config file missing: $USER_CONFIG_FILE"}
      ${ui.badges.error "Run system update with migration or create the file manually."}
      ${ui.badges.error "Aborting - the system would delete ALL users without a config."}
      exit 1
    fi
    CONFIG_RAW=$(cat "$USER_CONFIG_FILE" 2>/dev/null | tr -d '[:space:]#')
    if [ -z "$CONFIG_RAW" ] || [ "$CONFIG_RAW" = "{}" ]; then
      ${ui.badges.error "CRITICAL: User config file exists but is empty: $USER_CONFIG_FILE"}
      ${ui.badges.error "The file contains only comments/whitespace. No users are configured!"}
      ${ui.badges.error "Aborting - the system would delete ALL current users."}
      exit 1
    fi

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

      # HARTE ABBRECHEN wenn ALLE User entfernt würden
      if [ -z "$CONFIGURED_USERS" ] && [ ! -z "$CURRENT_USERS" ]; then
        ${ui.badges.error "CRITICAL: All existing system users would be removed!"}
        ${ui.badges.error "At least one admin/restricted-admin user is required."}
        ${ui.badges.error "Aborting. Configure a user or use --force to override."}
        exit 1
      fi

      # Ask for confirmation
      read -p "Continue with these changes? [y/N] " response
      if [[ ! "$response" =~ ^[Yy]$ ]]; then
        ${ui.badges.error "Aborting."}
        exit 1
      fi
    fi

    # PASSWORT-CHECK: Prüfe ob alle konfigurierten User ein Passwort haben
    PASSWORD_DIR="/etc/nixos/secrets/passwords"
    for user in $CONFIGURED_USERS; do
      if [ ! -f "$PASSWORD_DIR/$user/.hashedPassword" ]; then
        users_without_password="$users_without_password $user"
      fi
    done

    if [ -n "$users_without_password" ]; then
      echo ""
      ${ui.badges.warning "Password Check:"}
      for user in $users_without_password; do
        echo "  - $user: no declarative password found"
      done
      echo ""
      echo "Without a saved password, this user won't be able to login after rebuild."
      echo "Passwords are stored declaratively in $PASSWORD_DIR/<user>/.hashedPassword"
      read -p "Set missing passwords now? [Y/n] " pw_response
      if [[ ! "$pw_response" =~ ^[Nn]$ ]]; then
        for user in $users_without_password; do
          echo ""
          echo "Setting password for '$user'..."
          read -s -p "New password: " PASSWORD
          echo
          read -s -p "Retype new password: " PASSWORD_CONFIRM
          echo
          if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
            ${ui.badges.error "Passwords do not match"}
            continue
          fi
          HASH=$(echo "$PASSWORD" | ${pkgs.openssl}/bin/openssl passwd -6 -stdin)
          unset PASSWORD PASSWORD_CONFIRM
          if [ -n "$HASH" ]; then
            mkdir -p "$PASSWORD_DIR/$user"
            printf '%s' "$HASH" > "$PASSWORD_DIR/$user/.hashedPassword"
            chmod 600 "$PASSWORD_DIR/$user/.hashedPassword"
            chown root:root "$PASSWORD_DIR/$user/.hashedPassword"
            SHADOW_BEFORE=$(getent shadow "$user" 2>/dev/null)
            if echo "$user:$HASH" | ${pkgs.shadow}/bin/chpasswd -e; then
              SHADOW_AFTER=$(getent shadow "$user" 2>/dev/null)
              if echo "$SHADOW_AFTER" | grep -q "^$user:$HASH"; then
                ${ui.badges.success "Password set and saved for $user"}
              else
                ${ui.badges.error "chpasswd OK but shadow hash mismatch! File saved, rebuild required to apply password declaratively."}
              fi
            else
              ${ui.badges.warning "Hash saved but chpasswd failed (login may not work until rebuild)"}
            fi
          else
            ${ui.badges.error "Failed to generate password hash"}
          fi
        done
      fi
    fi
    ${ui.badges.success "User check complete"}
    exit 0
  '';

in {
  config = lib.mkMerge [
    {
      environment.systemPackages = [ prebuildScript ];
    }
    (cliRegistry.registerCommandsFor "system-checks-users" [
      {
        name = "check-users";
        domain = "system";
        category = "system-checks";
        internal = true;  # Don't show in main help - called by ncc system build
        description = "Check user configuration before system rebuild";
        script = "${prebuildScript}/bin/prebuild-check-users";
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
      }
      # Weitere Befehle können hier hinzugefügt werden
      ])
  ];
}
