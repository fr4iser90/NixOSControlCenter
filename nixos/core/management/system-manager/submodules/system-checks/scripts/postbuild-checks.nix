{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.core.management.system-manager.submodules.system-checks or {};
  postbuildCfg = cfg.postbuild or {};

  # Available postbuild checks
  postbuildChecks = {
    filesystem = {
      enable = postbuildCfg.checks.filesystem.enable or true;
      script = pkgs.writeScript "check-filesystem" ''
        #!${pkgs.bash}/bin/bash

        # Check important directories and permissions
        echo "Checking critical directories..."

        # System Directories
        dirs=(
          "/etc/nixos/secrets:root:root:700"
          "/etc/nixos/secrets/passwords:root:root:700"
        )

        # Add user-specific password directories
        for user in $(getent group wheel | cut -d: -f4 | tr ',' ' '); do
          dirs+=("/etc/nixos/secrets/passwords/$user:$user:users:700")
        done

        for dir_spec in "''${dirs[@]}"; do
          IFS=: read -r dir owner group perms <<< "$dir_spec"

          if [ ! -d "$dir" ]; then
            echo -e "''${YELLOW}⚠️  Creating $dir''${NC}"
            mkdir -p "$dir"
          fi

          current_perms=$(stat -c "%a" "$dir")
          current_owner=$(stat -c "%U" "$dir")
          current_group=$(stat -c "%G" "$dir")

          if [ "$current_perms" != "$perms" ] || \
             [ "$current_owner" != "$owner" ] || \
             [ "$current_group" != "$group" ]; then
            echo -e "''${YELLOW}⚠️  Fixing permissions for $dir''${NC}"
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

        # Check admin passwords
        for user in $(getent group wheel | cut -d: -f4 | tr ',' ' '); do
          if ! getent shadow "$user" | grep -q "^$user:[^\*\!:]"; then
            echo -e "''${YELLOW}⚠️  Admin user '$user' has no valid password!''${NC}"

            while true; do
              read -p "Do you want to set a password for $user now? [Y/n/s(skip)] " response
              case $response in
                [Nn]* )
                  echo "Password check failed."
                  exit 1
                  ;;
                [Ss]* )
                  echo "Skipping password for $user"
                  break
                  ;;
                * )
                  if passwd "$user"; then
                    echo -e "''${GREEN}✅ Password set successfully for $user''${NC}"
                    break
                  else
                    echo -e "''${RED}❌ Failed to set password, please try again''${NC}"
                  fi
                  ;;
              esac
            done
          fi
        done
      '';
    };

    services = {
      enable = postbuildCfg.checks.services.enable or true;
      script = pkgs.writeScript "check-services" ''
        #!${pkgs.bash}/bin/bash

        # Check critical system services
        echo "Checking critical services..."

        services=(
          "dbus"
          "systemd-logind"
          "polkit"
        )

        for service in "''${services[@]}"; do
          if ! systemctl is-active --quiet "$service"; then
            echo -e "''${RED}❌ Service $service is not running!''${NC}"
            echo "Attempting to start $service..."
            systemctl start "$service" || {
              echo -e "''${RED}Failed to start $service''${NC}"
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

    # Color definitions
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'

    echo -e "''${BLUE}=== NixOS postbuild Checks ===''${NC}"

    # Run all enabled checks
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: check:
      if check.enable then
        "echo -e \"\\n\\033[0;34mRunning ${name} check...\\033[0m\""
        + "\n''${check.script} || exit 1"
      else ""
    ) postbuildChecks)}

    echo -e "\\n\\033[0;32m✅ All postbuild checks passed\\033[0m"
  ''
