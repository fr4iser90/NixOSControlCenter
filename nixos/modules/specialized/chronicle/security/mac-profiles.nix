{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.chronicle.security.macProfiles;
in
{
  options.services.chronicle.security.macProfiles = {
    enable = mkEnableOption "Mandatory Access Control profiles (AppArmor/SELinux)";

    backend = mkOption {
      type = types.enum [ "apparmor" "selinux" ];
      default = "apparmor";
      description = "MAC backend to use";
    };

    profileMode = mkOption {
      type = types.enum [ "enforce" "complain" "audit" ];
      default = "enforce";
      description = "Profile enforcement mode";
    };

    allowedPaths = mkOption {
      type = types.listOf types.path;
      default = [
        "/home/*/.local/share/chronicle/**"
        "/home/*/.config/chronicle/**"
        "/var/log/chronicle/**"
        "/tmp/chronicle-*/**"
      ];
      description = "Paths allowed by MAC profile";
    };

    allowedCapabilities = mkOption {
      type = types.listOf types.str;
      default = [
        "CAP_DAC_READ_SEARCH"  # Read any file
        "CAP_DAC_OVERRIDE"      # Write any file (for screenshots)
      ];
      description = "Linux capabilities to allow";
    };

    allowedNetworkAccess = mkOption {
      type = types.bool;
      default = true;
      description = "Allow network access (needed for API, cloud upload)";
    };
  };

  config = mkIf cfg.enable {
    # AppArmor configuration
    security.apparmor = mkIf (cfg.backend == "apparmor") {
      enable = true;
      
      profiles = {
        chronicle = {
          enforce = cfg.profileMode == "enforce";
          
          profile = ''
            #include <tunables/global>
            
            /nix/store/*/bin/chronicle {
              #include <abstractions/base>
              #include <abstractions/X>
              
              # Executable
              /nix/store/*/bin/chronicle mr,
              /nix/store/** r,
              
              # Configuration and data
              ${concatMapStringsSep "\n  " (p: "${p} rw,") cfg.allowedPaths}
              
              # System access
              /proc/*/stat r,
              /proc/*/status r,
              /proc/meminfo r,
              /sys/devices/** r,
              
              # Screenshots
              /tmp/** rw,
              
              # X11/Wayland
              /tmp/.X11-unix/* rw,
              ${lib.optionalString config.services.xserver.enable ''/run/user/*/wayland-* rw,''}
              
              # Network (conditional)
              ${lib.optionalString cfg.allowedNetworkAccess ''
              network inet stream,
              network inet6 stream,
              network inet dgram,
              network inet6 dgram,
              ''}
              
              # Capabilities
              ${concatMapStringsSep "\n  " (c: "capability ${c},") cfg.allowedCapabilities}
              
              # Deny dangerous operations
              deny /etc/shadow r,
              deny /etc/passwd w,
              deny /boot/** w,
              deny /sys/** w,
              
              # Python interpreter
              /nix/store/*/bin/python3* ix,
            }
          '';
        };
      };
    };

    # SELinux configuration (placeholder for future implementation)
    assertions = [
      {
        assertion = cfg.backend != "selinux" || cfg.backend == "apparmor";
        message = "SELinux support is planned but not yet implemented. Use AppArmor instead.";
      }
    ];

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "chronicle-mac-profile" ''
      #!/usr/bin/env bash
      set -euo pipefail

      # MAC Profile Management
      BACKEND="${cfg.backend}"
      MODE="${cfg.profileMode}"

      show_status() {
          echo "=== MAC Profile Status ==="
          echo "Backend: $BACKEND"
          echo "Mode: $MODE"
          
          if [ "$BACKEND" = "apparmor" ]; then
              if command -v aa-status &> /dev/null; then
                  ${pkgs.apparmor-utils}/bin/aa-status | grep -i chronicle || echo "No chronicle profile loaded"
              else
                  echo "AppArmor not available"
              fi
          elif [ "$BACKEND" = "selinux" ]; then
              echo "SELinux support not yet implemented"
          fi
      }

      set_mode() {
          local mode="$1"
          
          if [ "$BACKEND" = "apparmor" ]; then
              case "$mode" in
                  enforce)
                      ${pkgs.apparmor-utils}/bin/aa-enforce chronicle
                      ;;
                  complain)
                      ${pkgs.apparmor-utils}/bin/aa-complain chronicle
                      ;;
                  audit)
                      ${pkgs.apparmor-utils}/bin/aa-audit chronicle
                      ;;
                  *)
                      echo "Unknown mode: $mode" >&2
                      exit 1
                      ;;
              esac
              echo "Set chronicle profile to $mode mode"
          fi
      }

      case "''${1:-status}" in
          status)
              show_status
              ;;
          enforce|complain|audit)
              set_mode "$1"
              ;;
          *)
              echo "Usage: $0 {status|enforce|complain|audit}" >&2
              exit 1
              ;;
      esac
      '')
    ];
  };
}
