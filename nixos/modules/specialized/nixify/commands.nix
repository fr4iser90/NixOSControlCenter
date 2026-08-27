{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  ui = getModuleApi "cli-formatter";
  systemMgrCfg = getModuleConfig "system-manager";
  hostLocalSourceDir = systemMgrCfg.localSourceDir or "";
  
  # Path to ISO builder
  isoBuilderPath = ./iso-builder;
  
  # Nixify Service Manager Script
  nixifyServiceScript = pkgs.writeScriptBin "ncc-nixify" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    ncc_cli_header() {
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        printf '%b\n' "\n${ui.colors.blue}=== $* ===${ui.colors.reset}"
      fi
    }
    ncc_cli_next() {
      if [ -z "''${NCC_CLI_NESTED:-}" ]; then
        printf '%b\n' "${ui.colors.blue}Next: $*${ui.colors.reset}"
      fi
    }

    ACTION=''${1:-help}

    case "$ACTION" in
      service)
        ncc_cli_header "Nixify"
        SUBACTION=''${2:-help}
        case "$SUBACTION" in
          start)
            ${ui.messages.loading "Starting Nixify web service…"}
            systemctl start nixify-service
            systemctl status nixify-service --no-pager || true
            ${ui.messages.success "Service start requested"}
            ncc_cli_next "ncc nixify service status"
            ;;
          stop)
            ${ui.messages.loading "Stopping Nixify web service…"}
            systemctl stop nixify-service
            ${ui.messages.success "Service stopped"}
            ncc_cli_next "ncc nixify service start"
            ;;
          status)
            ${ui.messages.loading "Checking Nixify web service…"}
            systemctl status nixify-service --no-pager || true
            ncc_cli_next "ncc nixify service restart"
            ;;
          restart)
            ${ui.messages.loading "Restarting Nixify web service…"}
            systemctl restart nixify-service
            systemctl status nixify-service --no-pager || true
            ${ui.messages.success "Service restarted"}
            ncc_cli_next "ncc nixify service logs"
            ;;
          logs)
            journalctl -u nixify-service -f
            ;;
          *)
            ${ui.messages.error "Usage: ncc nixify service {start|stop|status|restart|logs}"}
            exit 1
            ;;
        esac
        ;;
      list)
        ncc_cli_header "Nixify"
        ${ui.messages.warning "Session listing not yet implemented"}
        ncc_cli_next "ncc nixify service status"
        ;;
      show)
        ncc_cli_header "Nixify"
        SESSION_ID=''${2:-}
        if [ -z "$SESSION_ID" ]; then
          ${ui.messages.error "Usage: ncc nixify show <session-id>"}
          exit 1
        fi
        ${ui.messages.warning "Session details not yet implemented ($SESSION_ID)"}
        ncc_cli_next "ncc nixify list"
        ;;
      download)
        ncc_cli_header "Nixify"
        SESSION_ID=''${2:-}
        if [ -z "$SESSION_ID" ]; then
          ${ui.messages.error "Usage: ncc nixify download <session-id>"}
          exit 1
        fi
        ${ui.messages.warning "Download not yet implemented ($SESSION_ID)"}
        ncc_cli_next "ncc nixify show $SESSION_ID"
        ;;
      build-iso|iso)
        ncc_cli_header "Nixify ISO Build"
        DESKTOP_ENV=''${2:-plasma6}
        FORCE_REBUILD_FLAG="--arg forceRebuild false"
        VERBOSE=0

        if [ "''${2}" = "--force-rebuild" ] || [ "''${2}" = "-f" ]; then
          DESKTOP_ENV="plasma6"
          FORCE_REBUILD_FLAG="--arg forceRebuild true"
          ${ui.messages.info "Force rebuild enabled (ignoring cache)"}
        elif [ "''${3}" = "--force-rebuild" ] || [ "''${3}" = "-f" ]; then
          FORCE_REBUILD_FLAG="--arg forceRebuild true"
          ${ui.messages.info "Force rebuild enabled (ignoring cache)"}
        fi
        for arg in "$@"; do
          case "$arg" in -v|--verbose) VERBOSE=1 ;; esac
        done

        case "$DESKTOP_ENV" in
          gnome|plasma6)
            ${ui.messages.loading "Building NixOS ISO with Calamares and NixOS Control Center…"}
            ${ui.messages.info "Desktop environment: $DESKTOP_ENV"}
            ;;
          *)
            ${ui.messages.error "Invalid desktop environment: $DESKTOP_ENV"}
            ${ui.messages.info "Valid: gnome | plasma6 (default)"}
            ${ui.messages.info "Usage: ncc nixify build-iso [gnome|plasma6] [--force-rebuild|-f]"}
            ncc_cli_next "ncc nixify build-iso plasma6"
            exit 1
            ;;
        esac

        ISO_BUILDER_DIR=""
        if [ -d "./nixos/modules/specialized/nixify/iso-builder" ]; then
          ISO_BUILDER_DIR="./nixos/modules/specialized/nixify/iso-builder"
        elif [ -n "${hostLocalSourceDir}" ] && [ -d "${hostLocalSourceDir}/modules/specialized/nixify/iso-builder" ]; then
          ISO_BUILDER_DIR="${hostLocalSourceDir}/modules/specialized/nixify/iso-builder"
        elif [ -n "${hostLocalSourceDir}" ] && [ -d "${hostLocalSourceDir}/nixos/modules/specialized/nixify/iso-builder" ]; then
          ISO_BUILDER_DIR="${hostLocalSourceDir}/nixos/modules/specialized/nixify/iso-builder"
        elif [ -d "/etc/nixos/modules/specialized/nixify/iso-builder" ]; then
          ISO_BUILDER_DIR="/etc/nixos/modules/specialized/nixify/iso-builder"
        else
          CURRENT_DIR="$(pwd)"
          while [ "$CURRENT_DIR" != "/" ]; do
            if [ -d "$CURRENT_DIR/.git" ] && [ -d "$CURRENT_DIR/nixos/modules/specialized/nixify/iso-builder" ]; then
              ISO_BUILDER_DIR="$CURRENT_DIR/nixos/modules/specialized/nixify/iso-builder"
              break
            fi
            CURRENT_DIR="$(dirname "$CURRENT_DIR")"
          done
        fi

        if [ -z "$ISO_BUILDER_DIR" ] || [ ! -d "$ISO_BUILDER_DIR" ]; then
          if [ -d "${isoBuilderPath}" ]; then
            ISO_BUILDER_DIR="${isoBuilderPath}"
          else
            ${ui.messages.error "Could not find ISO builder directory"}
            ${ui.messages.info "Run from repository root: nixos/modules/specialized/nixify/iso-builder"}
            ncc_cli_next "cd /path/to/NixOSControlCenter && ncc nixify build-iso"
            exit 1
          fi
        fi

        cd "$ISO_BUILDER_DIR" || {
          ${ui.messages.error "Could not change to ISO builder directory: $ISO_BUILDER_DIR"}
          exit 1
        }

        ${ui.messages.info "Building ISO from: $(pwd)"}

        BUILD_SCRIPT="build-iso-''${DESKTOP_ENV}.nix"
        if [ ! -f "$BUILD_SCRIPT" ]; then
          ${ui.messages.warning "$BUILD_SCRIPT not found — falling back to build-iso.nix"}
          BUILD_SCRIPT="build-iso.nix"
        fi

        TEMP_BUILD_DIR=$(mktemp -d)
        TEMP_RESULT=$(mktemp -d)
        ABS_BUILD_SCRIPT="$(readlink -f "$BUILD_SCRIPT")"

        ${ui.messages.loading "nix-build in progress (this may take a while)…"}
        BUILD_EXIT=0
        (cd "$TEMP_BUILD_DIR" && nix-build "$ABS_BUILD_SCRIPT" $FORCE_REBUILD_FLAG --out-link "$TEMP_RESULT/result" 2>&1 | tee /tmp/nixify-build.log) || BUILD_EXIT=$?

        if [ "$VERBOSE" = "1" ] && [ -f /tmp/nixify-build.log ]; then
          DEBUG_LINES=$(grep "DEBUG:" /tmp/nixify-build.log || true)
          if [ -n "$DEBUG_LINES" ]; then
            ${ui.messages.info "Debug lines from build log:"}
            echo "$DEBUG_LINES"
          fi
        fi

        if [ $BUILD_EXIT -eq 0 ]; then
          RESULT_ISO_DIR="$HOME/.local/share/nixify/isos"
          mkdir -p "$RESULT_ISO_DIR"
          BUILT_ISO=$(find "$TEMP_RESULT/result/iso" -name "nixos-nixify-*.iso" 2>/dev/null | head -1)
          if [ -n "$BUILT_ISO" ]; then
            ISO_NAME=$(basename "$BUILT_ISO")
            TARGET_ISO="$RESULT_ISO_DIR/$ISO_NAME"
            if [ -f "$TARGET_ISO" ] && [ ! -w "$TARGET_ISO" ]; then
              ${ui.messages.warning "Removing existing ISO with wrong permissions: $TARGET_ISO"}
              rm -f "$TARGET_ISO" 2>/dev/null || true
            fi
            cp "$BUILT_ISO" "$TARGET_ISO"
            chmod 644 "$TARGET_ISO" 2>/dev/null || true
            ABS_ISO_PATH="$(readlink -f "$RESULT_ISO_DIR/$ISO_NAME")"
            ${ui.messages.success "ISO build successful"}
            ${ui.messages.info "ISO location: $ABS_ISO_PATH"}
            ncc_cli_next "qemu-system-x86_64 -cdrom \"$ABS_ISO_PATH\" -m 4G"
          else
            ${ui.messages.error "Could not find ISO file in build output"}
            ncc_cli_next "ncc nixify build-iso $DESKTOP_ENV -v"
            exit 1
          fi
        else
          ${ui.messages.error "ISO build failed"}
          ${ui.messages.info "Log: /tmp/nixify-build.log"}
          ncc_cli_next "ncc nixify build-iso $DESKTOP_ENV -v"
          exit 1
        fi
        ;;
      help|*)
        cat <<EOF
Nixify — Windows/macOS/Linux → NixOS System-DNA-Extractor

Usage: ncc nixify <command> [options]

Commands:
  service <action>       Manage web service (start|stop|status|restart|logs)
  build-iso|iso [env]    Build custom NixOS ISO (gnome|plasma6)
  list                   List sessions (not yet implemented)
  show <session-id>      Show session details (not yet implemented)
  download <session-id>  Download config/ISO (not yet implemented)

Examples:
  ncc nixify service start
  ncc nixify build-iso plasma6
  ncc nixify build-iso gnome --force-rebuild

See: doc/nixify-architecture.md
EOF
        exit 0
        ;;
    esac
  '';
in
{
  config = lib.mkMerge [
    (cliRegistry.registerCommandsFor "nixify" [
      {
        name = "nixify";
        domain = "nixify";
        type = "manager";
        description = "Windows/macOS/Linux → NixOS System-DNA-Extractor";
        script = "${nixifyServiceScript}/bin/ncc-nixify";
        category = "specialized";
        shortHelp = "nixify - Extract system DNA and generate NixOS configs";
        longHelp = ''
          Nixify helps users migrate from Windows/macOS/Linux to NixOS by:
          
          1. Extracting system state (installed programs, settings, hardware)
          2. Mapping programs to NixOS packages/modules
          3. Generating declarative NixOS configurations
          4. Building custom ISO images (optional)
          
          Usage:
            ncc nixify service start    # Start web service
            ncc nixify service status   # Check service status
            ncc nixify build-iso        # Build custom ISO with Calamares
            ncc nixify iso              # Alias for build-iso
            ncc nixify list             # List all sessions
            ncc nixify show <id>        # Show session details
            ncc nixify download <id>     # Download config/ISO
          
          For detailed documentation, see:
          - doc/nixify-architecture.md
          - doc/NIXIFY_WORKFLOW.md
        '';
      }
    ])
  ];
}
