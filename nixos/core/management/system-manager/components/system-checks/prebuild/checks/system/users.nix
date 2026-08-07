{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

let
  cliRegistry = getModuleApi "cli-registry";
  ui = getModuleApi "cli-formatter";
  hw = import ../../../../../lib/hardware-config-writer.nix { inherit pkgs lib systemConfig getModuleConfig; };

  prebuildScript = pkgs.writeScriptBin "prebuild-check-users" ''
    #!${pkgs.bash}/bin/bash
    set -e

    ${hw.preamble}

    VERBOSE="''${NCC_PREFLIGHT_VERBOSE:-0}"

    CURRENT_USERS=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 && $1 !~ /^nixbld/ {print $1}')
    CONFIGURED_USERS="${builtins.concatStringsSep " " (builtins.attrNames (lib.filterAttrs (n: v: builtins.isAttrs v) (getModuleConfig "user")))}"

    if [ "$VERBOSE" = "1" ]; then
      echo "  current:    $CURRENT_USERS"
      echo "  configured: $CONFIGURED_USERS"
    fi

    _user_config_present() {
      local layout
      layout=$(ncc_detect_layout 2>/dev/null || echo "split")
      case "$layout" in
        monolith)
          [[ -f "$MONOLITH_FILE" ]] || return 1
          local names
          names=$("''${NIX_INSTANTIATE_BIN:-nix-instantiate}" --eval --strict --json -E \
            "builtins.attrNames ((import $MONOLITH_FILE).core.base.user or {})" \
            2>/dev/null | tr -d '[]"' | tr ',' ' ')
          [[ -n "''${names// /}" ]]
          ;;
        *)
          local f="''${CONFIG_PATH_USER:-/etc/nixos/systemConfig/core/base/user/config.nix}"
          [[ -f "$f" ]] || return 1
          local raw
          raw=$(tr -d '[:space:]#' < "$f" 2>/dev/null || true)
          [[ -n "$raw" && "$raw" != "{}" ]]
          ;;
      esac
    }

    if ! _user_config_present; then
      ${ui.badges.error "Users: config missing or empty (would remove all users)"}
      if [ "$VERBOSE" = "1" ]; then
        echo "  layout=$(ncc_detect_layout 2>/dev/null || echo unknown)"
        echo "  monolith=$MONOLITH_FILE"
      fi
      exit 1
    fi

    changes_detected=0
    removed_users=""
    added_users=""
    users_without_password=""

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
      ${ui.badges.warning "Users: changes detected"}
      if [ -n "$removed_users" ]; then
        echo "  remove:$removed_users"
      fi
      if [ -n "$added_users" ]; then
        echo "  add:$added_users"
      fi

      if [ -z "$CONFIGURED_USERS" ] && [ -n "$CURRENT_USERS" ]; then
        ${ui.badges.error "Users: all users would be removed — aborting"}
        exit 1
      fi

      printf "Continue with these user changes? [y/N] "
      read -r response || response=""
      if [[ ! "$response" =~ ^[Yy]$ ]]; then
        ${ui.badges.error "Users: aborted"}
        exit 1
      fi
    fi

    PASSWORD_DIR="/etc/nixos/secrets/passwords"
    for user in $CONFIGURED_USERS; do
      if [ ! -f "$PASSWORD_DIR/$user/.hashedPassword" ]; then
        users_without_password="$users_without_password $user"
      fi
    done

    if [ -n "$users_without_password" ]; then
      ${ui.badges.warning "Users: missing passwords:$users_without_password"}
      printf "Set missing passwords now? [Y/n] "
      read -r pw_response || pw_response=""
      if [[ ! "$pw_response" =~ ^[Nn]$ ]]; then
        for user in $users_without_password; do
          echo "Setting password for '$user'..."
          read -s -p "New password: " PASSWORD
          echo
          read -s -p "Retype new password: " PASSWORD_CONFIRM
          echo
          if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
            ${ui.badges.error "Users: passwords do not match ($user)"}
            continue
          fi
          HASH=$(echo "$PASSWORD" | ${pkgs.openssl}/bin/openssl passwd -6 -stdin)
          unset PASSWORD PASSWORD_CONFIRM
          if [ -n "$HASH" ]; then
            mkdir -p "$PASSWORD_DIR/$user"
            printf '%s' "$HASH" > "$PASSWORD_DIR/$user/.hashedPassword"
            chmod 600 "$PASSWORD_DIR/$user/.hashedPassword"
            chown root:root "$PASSWORD_DIR/$user/.hashedPassword"
            if echo "$user:$HASH" | ${pkgs.shadow}/bin/chpasswd -e; then
              ${ui.badges.success "Users: password set for $user"}
            else
              ${ui.badges.warning "Users: hash saved for $user (chpasswd failed until rebuild)"}
            fi
          else
            ${ui.badges.error "Users: failed to hash password for $user"}
          fi
        done
      fi
    fi

    ${ui.badges.success "Users: $CONFIGURED_USERS"}
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
        internal = true;
        description = "Check user configuration before system rebuild";
        script = "${prebuildScript}/bin/prebuild-check-users";
        shortHelp = "check-users - Verify user configuration";
        longHelp = ''
          Check user configuration before system rebuild.
          Quiet by default; details with NCC_PREFLIGHT_VERBOSE=1.
        '';
        interactive = true;
        dependencies = [ "system-checks" ];
      }
    ])
  ];
}
