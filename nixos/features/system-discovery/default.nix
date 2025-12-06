{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  # CLI formatter API (Core module, always available)
  ui = config.core.cli-formatter.api;
  
  # Feature configuration
  cfg = config.features.system-discovery;
  
  # Import scanner modules (only those that don't use cfg can be in outer let)
  desktopScanner = import ./scanners/desktop.nix { inherit pkgs; };
  steamScanner = import ./scanners/steam.nix { inherit pkgs; };
  packagesScanner = import ./scanners/packages.nix { inherit pkgs; };
  browserScanner = import ./scanners/browser.nix { inherit pkgs; };
  ideScanner = import ./scanners/ide.nix { inherit pkgs; };
  
  # Note: Handlers and scanners that use cfg must be in mkIf cfg.enable block
  
in {
  imports = [
    ./options.nix
  ];

  config = mkMerge [
    # Default configuration - map systemConfig.features.system-discovery to config.features.system-discovery.enable
    {
      features.system-discovery = {
        enable = mkDefault (systemConfig.features.system-discovery or false);
      };
    }
    
    # Feature implementation (only when enabled)
    (mkIf cfg.enable (let
      # Import scanner that uses cfg
      credentialsScanner = import ./scanners/credentials.nix { inherit pkgs lib cfg; };
      
      # Snapshot generator
      snapshotGenerator = import ./snapshot-generator.nix { 
        inherit pkgs cfg;
        scanners = {
          desktop = desktopScanner;
          steam = steamScanner;
          credentials = credentialsScanner;
          packages = packagesScanner;
          browser = browserScanner;
          ide = ideScanner;
        };
      };
      
      # Encryption handler
      encryptionHandler = import ./encryption.nix { 
        inherit pkgs lib cfg;
      };
      
      # GitHub upload handler
      githubHandler = import ./github-upload.nix { 
        inherit pkgs lib cfg;
      };
      
      # GitHub download handler
      githubDownloadHandler = import ./github-download.nix { 
        inherit pkgs lib cfg;
      };
      
      # Restore handler
      restoreHandler = import ./restore.nix { 
        inherit pkgs cfg ui;
      };
      
      # Main discovery command scripts (for command-center registration)
      discoverScript = pkgs.writeShellScriptBin "ncc-discover-main" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail
    
    SNAPSHOT_DIR="${cfg.snapshotDir}"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    SNAPSHOT_FILE="$SNAPSHOT_DIR/system-snapshot_$TIMESTAMP.json"
    
    ${ui.messages.info "Starting system discovery..."}
    
    # Run all enabled scanners
    ${snapshotGenerator}/bin/generate-snapshot \
      --output "$SNAPSHOT_FILE" \
      ${optionalString cfg.scanners.desktop "--desktop"} \
      ${optionalString cfg.scanners.steam "--steam"} \
      ${optionalString cfg.scanners.credentials.enable "--credentials"} \
      ${optionalString cfg.scanners.packages "--packages"} \
      ${optionalString cfg.scanners.browser "--browser"} \
      ${optionalString cfg.scanners.ide "--ide"}
    
    ${ui.messages.success "Snapshot created: $SNAPSHOT_FILE"}
    
    # Encrypt if enabled
    if [ "${if cfg.encryption.enable then "true" else "false"}" = "true" ]; then
      ${ui.messages.info "Encrypting snapshot..."}
      ${encryptionHandler}/bin/encrypt-snapshot \
        --input "$SNAPSHOT_FILE" \
        --method "${cfg.encryption.method}" \
        ${optionalString (cfg.encryption.sops.keysFile != "") "--sops-keys ${cfg.encryption.sops.keysFile}"} \
        ${optionalString (cfg.encryption.sops.ageKeyFile != "") "--age-key ${cfg.encryption.sops.ageKeyFile}"} \
        ${optionalString (cfg.encryption.fido2.device != "") "--fido2-device ${cfg.encryption.fido2.device}"}
      
      ENCRYPTED_FILE="$SNAPSHOT_FILE.encrypted"
      ${ui.messages.success "Encrypted snapshot: $ENCRYPTED_FILE"}
      rm -f "$SNAPSHOT_FILE"  # Remove unencrypted version
    fi
    
    # Upload to GitHub if enabled
    if [ "${if cfg.github.enable then "true" else "false"}" = "true" ] && [ -n "${cfg.github.repository}" ]; then
      ${ui.messages.info "Uploading to GitHub..."}
      ${githubHandler}/bin/upload-to-github \
        --repository "${cfg.github.repository}" \
        --branch "${cfg.github.branch}" \
        ${optionalString (cfg.github.tokenFile != "") "--token-file ${cfg.github.tokenFile}"} \
        --snapshot "$SNAPSHOT_FILE${optionalString cfg.encryption.enable ".encrypted"}"
      
      ${ui.messages.success "Uploaded to GitHub"}
    fi
    
    ${ui.messages.success "System discovery complete!"}
  '';
  
  restoreScript = pkgs.writeShellScriptBin "ncc-restore-main" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    if [ $# -eq 0 ]; then
      echo "Usage: ncc-restore --snapshot <file> [options]"
      echo ""
      echo "Options:"
      echo "  --snapshot <file>    Snapshot file to restore from (required)"
      echo "  --browsers           Restore browser bookmarks and extensions list"
      echo "  --ides               Restore IDE settings and extensions list"
      echo "  --desktop            Restore desktop settings"
      echo "  --all                Restore everything"
      echo "  --dry-run            Show what would be restored without actually restoring"
      echo ""
      echo "Examples:"
      echo "  ncc-restore --snapshot /path/to/snapshot.json.encrypted --all"
      echo "  ncc-restore --snapshot snapshot.json --browsers --ides"
      echo "  ncc-restore --snapshot snapshot.json.encrypted --all --dry-run"
      exit 1
    fi
    
    ${restoreHandler}/bin/restore-snapshot "$@"
  '';
  
  fetchScript = pkgs.writeShellScriptBin "ncc-fetch-main" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    if [ $# -eq 0 ]; then
      echo "Usage: ncc-fetch [options]"
      echo ""
      echo "Options:"
      echo "  --repository <owner/repo>  GitHub repository (default: from config)"
      echo "  --branch <branch>          Git branch (default: main)"
      echo "  --snapshot <name>          Specific snapshot to download (default: latest)"
      echo "  --output <dir>             Output directory (default: snapshotDir from config)"
      echo "  --list                     List available snapshots only"
      echo "  --token-file <file>        Path to GitHub token file (default: from config)"
      echo ""
      echo "Examples:"
      echo "  ncc-fetch --list"
      echo "  ncc-fetch --snapshot system-snapshot_20240101_120000.json.encrypted"
      echo "  ncc-fetch --repository user/repo --snapshot latest"
      exit 1
    fi
    
    ${githubDownloadHandler}/bin/download-from-github "$@"
  '';
  
  restoreFromGitHubScript = pkgs.writeShellScriptBin "ncc-restore-from-github-main" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    # Convenience command: fetch and restore in one go
    SNAPSHOT_NAME=""
    RESTORE_OPTIONS="--all"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
      case $1 in
        --snapshot)
          SNAPSHOT_NAME="$2"
          shift 2
          ;;
        --browsers|--ides|--desktop|--all)
          RESTORE_OPTIONS="$1"
          shift
          ;;
        *)
          # Pass to both commands
          break
          ;;
      esac
    done
    
    # Download snapshot
    echo "📥 Fetching snapshot from GitHub..."
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT
    
    FETCH_ARGS=()
    [ -n "${cfg.github.repository}" ] && FETCH_ARGS+=("--repository" "${cfg.github.repository}")
    [ -n "${cfg.github.branch}" ] && FETCH_ARGS+=("--branch" "${cfg.github.branch}")
    [ -n "${cfg.github.tokenFile}" ] && FETCH_ARGS+=("--token-file" "${cfg.github.tokenFile}")
    [ -n "$SNAPSHOT_NAME" ] && FETCH_ARGS+=("--snapshot" "$SNAPSHOT_NAME")
    FETCH_ARGS+=("$@")
    
    if ${githubDownloadHandler}/bin/download-from-github \
      --output "$TEMP_DIR" \
      "''${FETCH_ARGS[@]}"; then
      
      # Find downloaded snapshot
      DOWNLOADED_SNAPSHOT=$(find "$TEMP_DIR" -name "*.json" -o -name "*.encrypted" | head -1)
      
      if [ -n "$DOWNLOADED_SNAPSHOT" ] && [ -f "$DOWNLOADED_SNAPSHOT" ]; then
        echo ""
        echo "🔄 Restoring from downloaded snapshot..."
        ${restoreHandler}/bin/restore-snapshot --snapshot "$DOWNLOADED_SNAPSHOT" $RESTORE_OPTIONS
      else
        echo "❌ Could not find downloaded snapshot"
        exit 1
      fi
    else
      echo "❌ Failed to download snapshot"
      exit 1
    fi
  '';
    in {
      core.command-center.commands = [
        {
          name = "discover";
          description = "Scan system and create encrypted snapshot";
          category = "system";
          script = "${discoverScript}/bin/ncc-discover-main";
          arguments = [];
          dependencies = [];
          shortHelp = "discover - Scan system state and create encrypted snapshot";
          longHelp = ''
            Scan the entire system state including:
            - Desktop settings (themes, dark mode, cursor, etc.)
            - Browser extensions and bookmarks
            - IDE extensions and settings
            - Steam games
            - Installed packages
            - Credential metadata
            
            The snapshot is automatically encrypted and optionally uploaded to GitHub.
          '';
        }
        {
          name = "restore";
          description = "Restore system state from snapshot";
          category = "system";
          script = "${restoreScript}/bin/ncc-restore-main";
          arguments = [ "--snapshot" "--browsers" "--ides" "--desktop" "--all" "--dry-run" ];
          dependencies = [];
          shortHelp = "restore --snapshot <file> [--browsers|--ides|--desktop|--all] - Restore from snapshot";
          longHelp = ''
            Restore system state from an encrypted or unencrypted snapshot.
            
            Options:
              --snapshot <file>    Snapshot file to restore from (required)
              --browsers           Restore browser bookmarks
              --ides               Restore IDE settings
              --desktop            Restore desktop settings
              --all                Restore everything
              --dry-run            Show what would be restored without actually restoring
            
            Examples:
              ncc restore --snapshot snapshot.json.encrypted --all
              ncc restore --snapshot snapshot.json --browsers --ides
          '';
        }
        {
          name = "fetch";
          description = "Download snapshots from GitHub";
          category = "system";
          script = "${fetchScript}/bin/ncc-fetch-main";
          arguments = [ "--repository" "--branch" "--snapshot" "--output" "--list" "--token-file" ];
          dependencies = [];
          shortHelp = "fetch [--list|--snapshot <name>] - Download snapshots from GitHub";
          longHelp = ''
            Download system snapshots from GitHub repository.
            
            Options:
              --list                List available snapshots only
              --snapshot <name>     Specific snapshot to download (default: latest)
              --repository <repo>  GitHub repository (default: from config)
              --branch <branch>     Git branch (default: main)
              --output <dir>        Output directory (default: from config)
              --token-file <file>   GitHub token file (default: from config)
            
            Examples:
              ncc fetch --list
              ncc fetch --snapshot system-snapshot_20240101_120000.json.encrypted
          '';
        }
        {
          name = "restore-from-github";
          description = "Download and restore snapshot from GitHub";
          category = "system";
          script = "${restoreFromGitHubScript}/bin/ncc-restore-from-github-main";
          arguments = [ "--snapshot" "--browsers" "--ides" "--desktop" "--all" ];
          dependencies = [];
          shortHelp = "restore-from-github [--snapshot <name>] [--all] - Fetch and restore from GitHub";
          longHelp = ''
            Download the latest (or specific) snapshot from GitHub and restore it.
            This is a convenience command that combines fetch and restore.
            
            Options:
              --snapshot <name>    Specific snapshot to download (default: latest)
              --browsers           Restore browser bookmarks only
              --ides               Restore IDE settings only
              --desktop            Restore desktop settings only
              --all                Restore everything (default)
            
            Examples:
              ncc restore-from-github --all
              ncc restore-from-github --snapshot system-snapshot_20240101_120000.json.encrypted --browsers
          '';
        }
      ];
      
      # Feature implementation
      # Create snapshot directory
      systemd.tmpfiles.rules = [
        "d ${cfg.snapshotDir} 0755 root root -"
      ];
      
      # Optional: Systemd timer for automatic scanning
      systemd.timers.ncc-discover = mkIf (cfg.scanInterval != "") {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.scanInterval;
          Persistent = true;
        };
      };
      
      systemd.services.ncc-discover = mkIf (cfg.scanInterval != "") {
        serviceConfig.Type = "oneshot";
        script = ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail
          
          SNAPSHOT_DIR="${cfg.snapshotDir}"
          TIMESTAMP=$(date +%Y%m%d_%H%M%S)
          SNAPSHOT_FILE="$SNAPSHOT_DIR/system-snapshot_$TIMESTAMP.json"
          
          ${ui.messages.info "Starting system discovery..."}
          
          # Run all enabled scanners
          ${snapshotGenerator}/bin/generate-snapshot \
            --output "$SNAPSHOT_FILE" \
            ${optionalString cfg.scanners.desktop "--desktop"} \
            ${optionalString cfg.scanners.steam "--steam"} \
            ${optionalString cfg.scanners.credentials.enable "--credentials"} \
            ${optionalString cfg.scanners.packages "--packages"} \
            ${optionalString cfg.scanners.browser "--browser"} \
            ${optionalString cfg.scanners.ide "--ide"}
          
          ${ui.messages.success "Snapshot created: $SNAPSHOT_FILE"}
          
          # Encrypt if enabled
          if [ "${if cfg.encryption.enable then "true" else "false"}" = "true" ]; then
            ${ui.messages.info "Encrypting snapshot..."}
            ${encryptionHandler}/bin/encrypt-snapshot \
              --input "$SNAPSHOT_FILE" \
              --method "${cfg.encryption.method}" \
              ${optionalString (cfg.encryption.sops.keysFile != "") "--sops-keys ${cfg.encryption.sops.keysFile}"} \
              ${optionalString (cfg.encryption.sops.ageKeyFile != "") "--age-key ${cfg.encryption.sops.ageKeyFile}"} \
              ${optionalString (cfg.encryption.fido2.device != "") "--fido2-device ${cfg.encryption.fido2.device}"}
            
            ENCRYPTED_FILE="$SNAPSHOT_FILE.encrypted"
            ${ui.messages.success "Encrypted snapshot: $ENCRYPTED_FILE"}
            rm -f "$SNAPSHOT_FILE"  # Remove unencrypted version
          fi
          
          # Upload to GitHub if enabled
          if [ "${if cfg.github.enable then "true" else "false"}" = "true" ] && [ -n "${cfg.github.repository}" ]; then
            ${ui.messages.info "Uploading to GitHub..."}
            ${githubHandler}/bin/upload-to-github \
              --repository "${cfg.github.repository}" \
              --branch "${cfg.github.branch}" \
              ${optionalString (cfg.github.tokenFile != "") "--token-file ${cfg.github.tokenFile}"} \
              --snapshot "$SNAPSHOT_FILE${optionalString cfg.encryption.enable ".encrypted"}"
            
            ${ui.messages.success "Uploaded to GitHub"}
          fi
          
          ${ui.messages.success "System discovery complete!"}
        '';
      };
    }))
  ];
}

