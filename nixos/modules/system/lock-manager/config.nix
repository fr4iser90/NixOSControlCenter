{ config, lib, pkgs, systemConfig, moduleConfig, ... }:

with lib;

let
  # CLI formatter API - Vollständig API-basiert, kein hardcoded Pfad!
  ui = config.${moduleConfig.apiPath}.formatter or (import ../../core/management/system-manager/submodules/cli-formatter/lib/colors.nix { inherit lib; });

  # Feature configuration - API-basiert, kein hardcoded Pfad!
  cfg = systemConfig.${moduleConfig.configPath};

in
  lib.mkIf (cfg.enable or false) (let
    # Import collector modules (only those that don't use cfg can be in outer let)
    desktopScanner = import ./collectors/desktop.nix { inherit pkgs; };
    steamScanner = import ./collectors/steam.nix { inherit pkgs; };
    packagesScanner = import ./collectors/packages.nix { inherit pkgs; };
    browserScanner = import ./collectors/browser.nix { inherit pkgs; };
    ideScanner = import ./collectors/ide.nix { inherit pkgs; };

    # Import collector that uses cfg
    credentialsScanner = import ./collectors/credentials.nix { inherit pkgs lib cfg; };

    # Snapshot generator
    snapshotGenerator = import ./handlers/snapshot-generator.nix {
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
    encryptionHandler = import ./handlers/encryption.nix {
      inherit pkgs lib cfg;
    };

    # GitHub upload handler
    githubHandler = import ./handlers/github-upload.nix {
      inherit pkgs lib cfg;
    };

  in {
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
  })
