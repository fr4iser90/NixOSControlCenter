{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

let
  cfg = getModuleConfig "system-checks";
  postbuildCfg = cfg.postbuild or {};
  ui = getModuleApi "cli-formatter";

  postbuildChecks = {
    filesystem = {
      enable = postbuildCfg.checks.filesystem.enable or true;
      script = pkgs.writeScript "check-filesystem" ''
        #!${pkgs.bash}/bin/bash

        ${ui.messages.loading "Checking critical directories…"}

        dirs=(
          "/etc/nixos/secrets:root:root:700"
          "/etc/nixos/secrets/passwords:root:root:700"
        )

        for user in $(getent group wheel | cut -d: -f4 | tr ',' ' '); do
          dirs+=("/etc/nixos/secrets/passwords/$user:$user:users:700")
        done

        for dir_spec in "''${dirs[@]}"; do
          IFS=: read -r dir owner group perms <<< "$dir_spec"

          if [ ! -d "$dir" ]; then
            ${ui.messages.warning "Creating $dir"}
            mkdir -p "$dir"
          fi

          current_perms=$(stat -c "%a" "$dir")
          current_owner=$(stat -c "%U" "$dir")
          current_group=$(stat -c "%G" "$dir")

          if [ "$current_perms" != "$perms" ] || \
             [ "$current_owner" != "$owner" ] || \
             [ "$current_group" != "$group" ]; then
            ${ui.messages.warning "Fixing permissions for $dir"}
            chown "$owner:$group" "$dir"
            chmod "$perms" "$dir"
          fi
        done
      '';
    };

    passwords = {
      enable = postbuildCfg.checks.passwords.enable or true;
      script = pkgs.writeScript "check-passwords" ''
        #!${pkgs.bash}/bin/bash

        for user in $(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 && $1 !~ /^nixbld/ {print $1}'); do
          SHADOW_LINE=$(getent shadow "$user" 2>/dev/null)
          SHADOW_HASH=$(echo "$SHADOW_LINE" | cut -d: -f2)

          if echo "$SHADOW_HASH" | grep -q '^[!\*]' || [ -z "$SHADOW_HASH" ]; then
            ${ui.messages.warning "User '$user' has no valid password"}

            while true; do
              printf "Set a password for %s now? [Y/n/s(skip)] " "$user"
              read -r response
              case $response in
                [Nn]* )
                  ${ui.messages.error "Password check failed"}
                  exit 1
                  ;;
                [Ss]* )
                  ${ui.messages.info "Skipping password for $user"}
                  break
                  ;;
                * )
                  if passwd "$user"; then
                    ${ui.messages.success "Password set for $user"}
                    break
                  else
                    ${ui.messages.error "Failed to set password — try again"}
                  fi
                  ;;
              esac
            done
          fi

          HASH_FILE="/etc/nixos/secrets/passwords/$user/.hashedPassword"
          if [ -f "$HASH_FILE" ]; then
            EXPECTED_HASH=$(cat "$HASH_FILE")
            SHADOW_HASH=$(echo "$SHADOW_LINE" | cut -d: -f2)
            if [ -n "$SHADOW_HASH" ] && [ "$SHADOW_HASH" != "!" ] && [ "$SHADOW_HASH" != "*" ] && [ "$SHADOW_HASH" != "$EXPECTED_HASH" ]; then
              ${ui.messages.warning "Password hash mismatch for '$user'"}
              ${ui.messages.info "Run: sudo ncc system build switch"}
            fi
          fi
        done
      '';
    };

    services = {
      enable = postbuildCfg.checks.services.enable or true;
      script = pkgs.writeScript "check-services" ''
        #!${pkgs.bash}/bin/bash

        ${ui.messages.loading "Checking critical services…"}

        services=(
          "dbus"
          "systemd-logind"
          "polkit"
        )

        for service in "''${services[@]}"; do
          if ! systemctl is-active --quiet "$service"; then
            ${ui.messages.error "Service $service is not running"}
            ${ui.messages.loading "Starting $service…"}
            systemctl start "$service" || {
              ${ui.messages.error "Failed to start $service"}
              exit 1
            }
          fi
        done
      '';
    };
  };
in
  pkgs.writeScriptBin "nixos-postbuild" ''
    #!${pkgs.bash}/bin/bash
    set -e

    if [ -z "''${NCC_CLI_NESTED:-}" ]; then
      ${ui.text.header "NixOS postbuild checks"}
    else
      ${ui.messages.loading "Running postbuild checks…"}
    fi

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: check:
      if check.enable then
        ''
          ${check.script} || exit 1
          ${ui.badges.success "${name}"}
        ''
      else ""
    ) postbuildChecks)}

    ${ui.messages.success "All postbuild checks passed"}
    if [ -z "''${NCC_CLI_NESTED:-}" ]; then
      ${ui.messages.info "Next: ncc system build switch  (if you still need a rebuild)"}
    fi
  ''
