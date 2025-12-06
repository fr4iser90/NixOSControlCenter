{ config, lib, pkgs, systemConfig, ... }:

with lib;

let

  
  # Import scanner modules
  desktopScanner = import ./scanners/desktop.nix { inherit pkgs; };
  steamScanner = import ./scanners/steam.nix { inherit pkgs; };
  credentialsScanner = import ./scanners/credentials.nix { inherit pkgs cfg; };
  packagesScanner = import ./scanners/packages.nix { inherit pkgs; };
  browserScanner = import ./scanners/browser.nix { inherit pkgs; };
  ideScanner = import ./scanners/ide.nix { inherit pkgs; };
  
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
    inherit pkgs cfg;
  };
  
  # GitHub upload handler
  githubHandler = import ./github-upload.nix { 
    inherit pkgs cfg;
  };
  
  # GitHub download handler
  githubDownloadHandler = import ./github-download.nix { 
    inherit pkgs cfg;
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
    if [ "${toString cfg.encryption.enable}" = "true" ]; then
      ${ui.messages.info "Encrypting snapshot..."}
      ${encryptionHandler}/bin/encrypt-snapshot \
        --input "$SNAPSHOT_FILE" \
        --method "${cfg.encryption.method}" \
        ${optionalString (cfg.encryption.sops.keysFile != null) "--sops-keys ${cfg.encryption.sops.keysFile}"} \
        ${optionalString (cfg.encryption.sops.ageKeyFile != null) "--age-key ${cfg.encryption.sops.ageKeyFile}"} \
        ${optionalString (cfg.encryption.fido2.device != null) "--fido2-device ${cfg.encryption.fido2.device}"}
      
      ENCRYPTED_FILE="$SNAPSHOT_FILE.encrypted"
      ${ui.messages.success "Encrypted snapshot: $ENCRYPTED_FILE"}
      rm -f "$SNAPSHOT_FILE"  # Remove unencrypted version
    fi
    
    # Upload to GitHub if enabled
    if [ "${toString cfg.github.enable}" = "true" ] && [ -n "${cfg.github.repository}" ]; then
      ${ui.messages.info "Uploading to GitHub..."}
      ${githubHandler}/bin/upload-to-github \
        --repository "${cfg.github.repository}" \
        --branch "${cfg.github.branch}" \
        ${optionalString (cfg.github.tokenFile != null) "--token-file ${cfg.github.tokenFile}"} \
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
    [ -n "${cfg.github.repository or ""}" ] && FETCH_ARGS+=("--repository" "${cfg.github.repository}")
    [ -n "${cfg.github.branch or ""}" ] && FETCH_ARGS+=("--branch" "${cfg.github.branch}")
    [ -n "${cfg.github.tokenFile or ""}" ] && FETCH_ARGS+=("--token-file" "${cfg.github.tokenFile}")
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
  options.features.system-discovery = {
    enable = mkEnableOption "system discovery and snapshot";
    
    scanInterval = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Systemd timer interval for automatic scanning (e.g., 'daily', 'weekly', 'monthly')";
      example = "daily";
    };
    
    snapshotDir = mkOption {
      type = types.str;
      default = "/var/lib/nixos-control-center/snapshots";
      description = "Directory where snapshots are stored";
    };
    
    encryption = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable encryption for snapshots";
      };
      
      method = mkOption {
        type = types.enum [ "sops" "fido2" "both" ];
        default = "both";
        description = "Encryption method: sops, fido2, or both";
      };
      
      sops = {
        keysFile = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Path to sops keys file";
        };
        
        ageKeyFile = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Path to age key file for sops";
        };
      };
      
      fido2 = {
        device = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "FIDO2 device path (e.g., /dev/hidraw0)";
        };
        
        pin = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "FIDO2 PIN (leave null to prompt interactively)";
        };
      };
    };
    
    github = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable automatic upload to GitHub";
      };
      
      repository = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "GitHub repository (format: owner/repo)";
      };
      
      branch = mkOption {
        type = types.str;
        default = "main";
        description = "Git branch to push to";
      };
      
      tokenFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to file containing GitHub token (encrypted with sops recommended)";
      };
    };
    
    scanners = {
      desktop = mkOption {
        type = types.bool;
        default = true;
        description = "Scan desktop settings (themes, dark mode, cursor, etc.)";
      };
      
      steam = mkOption {
        type = types.bool;
        default = true;
        description = "Scan installed Steam games";
      };
      
      credentials = mkOption {
        type = types.submodule {
          options = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Enable credential scanning";
            };
            
            includePrivateKeys = mkOption {
              type = types.bool;
              default = false;
              description = "⚠️ WARNING: Include private keys in encrypted snapshot (security risk!)";
            };
            
            keyTypes = mkOption {
              type = types.listOf (types.enum [ "ssh" "gpg" ]);
              default = [ "ssh" "gpg" ];
              description = "Which key types to scan";
            };
            
            requireFIDO2 = mkOption {
              type = types.bool;
              default = true;
              description = "Require FIDO2 encryption if private keys are included";
            };
          };
        };
        default = {
          enable = true;
          includePrivateKeys = false;
          keyTypes = [ "ssh" "gpg" ];
          requireFIDO2 = true;
        };
        description = "Credential scanner configuration";
      };
      
      packages = mkOption {
        type = types.bool;
        default = true;
        description = "Scan installed packages";
      };
      
      browser = mkOption {
        type = types.bool;
        default = true;
        description = "Scan browser extensions, tabs, and settings";
      };
      
      ide = mkOption {
        type = types.bool;
        default = true;
        description = "Scan IDE extensions, plugins, and settings";
      };
    };
    
    audit = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable audit logging";
      };
      
      logFile = mkOption {
        type = types.str;
        default = "/var/log/ncc-discovery-audit.log";
        description = "Path to audit log file";
      };
      
      logLevel = mkOption {
        type = types.enum [ "debug" "info" "warn" "error" ];
        default = "info";
        description = "Audit log level";
      };
    };
    
    retention = {
      maxSnapshots = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Maximum number of snapshots to keep (null = unlimited)";
      };
      
      maxAge = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Maximum age of snapshots (e.g., '90d', '12w', '1y')";
      };
      
      compressOld = mkOption {
        type = types.bool;
        default = false;
        description = "Compress snapshots older than retention period";
      };
    };
    
    compliance = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable compliance checks";
      };
      
      requireEncryption = mkOption {
        type = types.bool;
        default = true;
        description = "Fail if encryption is disabled";
      };
      
      requireGitHubBackup = mkOption {
        type = types.bool;
        default = false;
        description = "Require GitHub backup to be enabled";
      };
      
      dataClassification = mkOption {
        type = types.enum [ "public" "internal" "confidential" "restricted" ];
        default = "internal";
        description = "Data classification level";
      };
    };
  };

  config = mkMerge [
    # Default configuration - map systemConfig.features.system-discovery to config.features.system-discovery.enable
    {
      features.system-discovery = {
        enable = mkDefault (systemConfig.features.system-discovery or false);
      };
    }
    
    # Register commands in command-center (only when feature is enabled)
    (mkIf cfg.enable {
      features.command-center.commands = [
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
    })
    
    # Feature implementation (only when enabled)
    (mkIf cfg.enable {
      # Create snapshot directory
      systemd.tmpfiles.rules = [
        "d ${cfg.snapshotDir} 0755 root root -"
      ];
      
      # Optional: Systemd timer for automatic scanning
      systemd.timers.ncc-discover = mkIf (cfg.scanInterval != null) {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.scanInterval;
          Persistent = true;
        };
      };
      
      systemd.services.ncc-discover = mkIf (cfg.scanInterval != null) {
        serviceConfig.Type = "oneshot";
        script = ''
          ${pkgs.writeShellScriptBin "ncc-discover" ''
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
            if [ "${toString cfg.encryption.enable}" = "true" ]; then
              ${ui.messages.info "Encrypting snapshot..."}
              ${encryptionHandler}/bin/encrypt-snapshot \
                --input "$SNAPSHOT_FILE" \
                --method "${cfg.encryption.method}" \
                ${optionalString (cfg.encryption.sops.keysFile != null) "--sops-keys ${cfg.encryption.sops.keysFile}"} \
                ${optionalString (cfg.encryption.sops.ageKeyFile != null) "--age-key ${cfg.encryption.sops.ageKeyFile}"} \
                ${optionalString (cfg.encryption.fido2.device != null) "--fido2-device ${cfg.encryption.fido2.device}"}
              
              ENCRYPTED_FILE="$SNAPSHOT_FILE.encrypted"
              ${ui.messages.success "Encrypted snapshot: $ENCRYPTED_FILE"}
              rm -f "$SNAPSHOT_FILE"  # Remove unencrypted version
            fi
            
            # Upload to GitHub if enabled
            if [ "${toString cfg.github.enable}" = "true" ] && [ -n "${cfg.github.repository}" ]; then
              ${ui.messages.info "Uploading to GitHub..."}
              ${githubHandler}/bin/upload-to-github \
                --repository "${cfg.github.repository}" \
                --branch "${cfg.github.branch}" \
                ${optionalString (cfg.github.tokenFile != null) "--token-file ${cfg.github.tokenFile}"} \
                --snapshot "$SNAPSHOT_FILE${optionalString cfg.encryption.enable ".encrypted"}"
              
              ${ui.messages.success "Uploaded to GitHub"}
            fi
            
            ${ui.messages.success "System discovery complete!"}
          ''}/bin/ncc-discover
        '';
      };
    })
  ];
}

