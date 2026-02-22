{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, nixifyModuleName, ... }:

with lib;

let
  # moduleName aus _module.args - NUR EINMAL berechnet in default.nix!
  moduleName = nixifyModuleName;
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  
  # Path to ISO builder
  isoBuilderPath = ./iso-builder;
  
  # Nixify Service Manager Script
  nixifyServiceScript = pkgs.writeScriptBin "ncc-nixify" ''
    #!${pkgs.bash}/bin/bash
    # Nixify Service Manager
    
    set -euo pipefail
    
    ACTION=''${1:-help}
    
    case "$ACTION" in
      service)
        SUBACTION=''${2:-help}
        case "$SUBACTION" in
          start)
            echo "Starting Nixify web service..."
            systemctl start nixify-service
            systemctl status nixify-service
            ;;
          stop)
            echo "Stopping Nixify web service..."
            systemctl stop nixify-service
            ;;
          status)
            systemctl status nixify-service
            ;;
          restart)
            echo "Restarting Nixify web service..."
            systemctl restart nixify-service
            systemctl status nixify-service
            ;;
          logs)
            journalctl -u nixify-service -f
            ;;
          *)
            echo "Usage: ncc nixify service {start|stop|status|restart|logs}"
            exit 1
            ;;
        esac
        ;;
      list)
        echo "Listing Nixify sessions..."
        # TODO: Implement session listing
        echo "Session listing not yet implemented"
        ;;
      show)
        SESSION_ID=''${2:-}
        if [ -z "$SESSION_ID" ]; then
          echo "Usage: ncc nixify show <session-id>"
          exit 1
        fi
        echo "Showing session: $SESSION_ID"
        # TODO: Implement session details
        echo "Session details not yet implemented"
        ;;
      download)
        SESSION_ID=''${2:-}
        if [ -z "$SESSION_ID" ]; then
          echo "Usage: ncc nixify download <session-id>"
          exit 1
        fi
        echo "Downloading session: $SESSION_ID"
        # TODO: Implement download
        echo "Download not yet implemented"
        ;;
      build-iso|iso)
        DESKTOP_ENV=''${2:-plasma6}  # Default: Plasma 6
        
        # Validate desktop environment
        case "$DESKTOP_ENV" in
          gnome|plasma6|xfce)
            echo "Building NixOS ISO with Calamares and NixOS Control Center..."
            echo "Desktop Environment: $DESKTOP_ENV"
            echo ""
            ;;
          *)
            echo "Error: Invalid desktop environment: $DESKTOP_ENV"
            echo ""
            echo "Valid options:"
            echo "  gnome    - GNOME Desktop"
            echo "  plasma6  - KDE Plasma 6 (default)"
            echo "  xfce     - XFCE Desktop"
            echo ""
            echo "Usage: ncc nixify build-iso [gnome|plasma6|xfce]"
            exit 1
            ;;
        esac
        
        # Get absolute path to ISO builder
        # The isoBuilderPath is set by Nix, but we need to resolve it at runtime
        # Try multiple strategies to find the ISO builder directory
        
        ISO_BUILDER_DIR=""
        
        # Strategy 1: Try to find it relative to current working directory
        if [ -d "./nixos/modules/specialized/nixify/iso-builder" ]; then
          ISO_BUILDER_DIR="./nixos/modules/specialized/nixify/iso-builder"
        # Strategy 2: Try common repository locations
        elif [ -d "$HOME/Documents/Git/NixOSControlCenter/nixos/modules/specialized/nixify/iso-builder" ]; then
          ISO_BUILDER_DIR="$HOME/Documents/Git/NixOSControlCenter/nixos/modules/specialized/nixify/iso-builder"
        elif [ -d "$HOME/nixos-control-center/nixos/modules/specialized/nixify/iso-builder" ]; then
          ISO_BUILDER_DIR="$HOME/nixos-control-center/nixos/modules/specialized/nixify/iso-builder"
        # Strategy 3: Try to find repository root by looking for .git
        else
          # Find repository root by looking for .git directory
          CURRENT_DIR="$(pwd)"
          while [ "$CURRENT_DIR" != "/" ]; do
            if [ -d "$CURRENT_DIR/.git" ] && [ -d "$CURRENT_DIR/nixos/modules/specialized/nixify/iso-builder" ]; then
              ISO_BUILDER_DIR="$CURRENT_DIR/nixos/modules/specialized/nixify/iso-builder"
              break
            fi
            CURRENT_DIR="$(dirname "$CURRENT_DIR")"
          done
        fi
        
        # If still not found, try to use the path from Nix (might be in store)
        if [ -z "$ISO_BUILDER_DIR" ] || [ ! -d "$ISO_BUILDER_DIR" ]; then
          # The path from Nix might be a store path, try it
          if [ -d "${isoBuilderPath}" ]; then
            ISO_BUILDER_DIR="${isoBuilderPath}"
          else
            echo "Error: Could not find ISO builder directory"
            echo ""
            echo "Please run from repository root or ensure the directory exists:"
            echo "  nixos/modules/specialized/nixify/iso-builder"
            echo ""
            echo "Current directory: $(pwd)"
            exit 1
          fi
        fi
        
        # Change to ISO builder directory
        cd "$ISO_BUILDER_DIR" || {
          echo "Error: Could not change to ISO builder directory: $ISO_BUILDER_DIR"
          exit 1
        }
        
        echo "Building ISO from: $(pwd)"
        echo ""
        
        # Select build script based on desktop environment
        BUILD_SCRIPT="build-iso-''${DESKTOP_ENV}.nix"
        if [ ! -f "$BUILD_SCRIPT" ]; then
          echo "Error: $BUILD_SCRIPT not found in $ISO_BUILDER_DIR"
          echo "Falling back to build-iso.nix with default (plasma6)"
          BUILD_SCRIPT="build-iso.nix"
        fi
        
        # Build ISO
        nix-build "$BUILD_SCRIPT"
        
        if [ $? -eq 0 ]; then
          echo ""
          echo "✅ ISO build successful!"
          echo ""
          ISO_FILE=$(find result/iso -name "nixos-nixify-*.iso" 2>/dev/null | head -1)
          if [ -n "$ISO_FILE" ]; then
            ABS_ISO_PATH="$(readlink -f "$ISO_FILE")"
            echo "ISO location: $ABS_ISO_PATH"
            echo ""
            echo "To test in QEMU:"
            echo "  qemu-system-x86_64 -cdrom \"$ABS_ISO_PATH\" -m 4G"
            echo ""
            echo "To write to USB:"
            echo "  sudo dd if=\"$ABS_ISO_PATH\" of=/dev/sdX bs=4M status=progress"
          else
            echo "ISO location: $(pwd)/result/iso/nixos-nixify-*.iso"
            echo ""
            echo "To test in QEMU:"
            echo "  qemu-system-x86_64 -cdrom result/iso/nixos-nixify-*.iso -m 4G"
            echo ""
            echo "To write to USB:"
            echo "  sudo dd if=result/iso/nixos-nixify-*.iso of=/dev/sdX bs=4M status=progress"
          fi
        else
          echo ""
          echo "❌ ISO build failed!"
          exit 1
        fi
        ;;
      help|*)
        cat <<EOF
Nixify - Windows/macOS/Linux → NixOS System-DNA-Extractor

Usage: ncc nixify <command> [options]

Commands:
  service <action>    Manage web service
    start             Start web service
    stop              Stop web service
    status            Show service status
    restart           Restart web service
    logs              Show service logs (follow mode)
  
         build-iso|iso [env] Build custom NixOS ISO with Calamares
                             Options: gnome, plasma6 (default), xfce
  list                List all sessions
  show <session-id>   Show session details
  download <session-id>  Download config/ISO for session
  
Examples:
  ncc nixify service start    # Start web service
  ncc nixify service status   # Check service status
         ncc nixify build-iso        # Build ISO with Plasma 6 (default)
         ncc nixify build-iso gnome  # Build ISO with GNOME
         ncc nixify build-iso plasma6 # Build ISO with Plasma 6
         ncc nixify build-iso xfce   # Build ISO with XFCE
         ncc nixify iso              # Alias for build-iso
  ncc nixify list             # List all sessions
  ncc nixify show abc123      # Show session details
  ncc nixify download abc123  # Download config/ISO

For more information, see: doc/NIXIFY_ARCHITECTURE.md
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
          - doc/NIXIFY_ARCHITECTURE.md
          - doc/NIXIFY_WORKFLOW.md
        '';
      }
    ])
  ];
}
