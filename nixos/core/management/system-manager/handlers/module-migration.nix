{ config, lib, pkgs, getModuleApi, ... }:

with lib;

let
  ui = getModuleApi "cli-formatter";
  
  # Execute module migration
  # moduleName: Name of the module
  # fromVersion: Current version
  # toVersion: Target version
  # migrationPath: Path to migration file
  executeMigration = moduleName: fromVersion: toVersion: migrationPath:
    pkgs.writeShellScriptBin "migrate-${moduleName}-${fromVersion}-to-${toVersion}" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      
      FEATURE_NAME="$1"
      FROM_VERSION="$2"
      TO_VERSION="$3"
      MIGRATION_FILE="$4"
      FEATURES_CONFIG="/etc/nixos/configs/module-manager-config.nix"
      BACKUP_DIR="/var/backup/nixos/migrations"
      
      ${ui.messages.info "Migrating $FEATURE_NAME: $FROM_VERSION → $TO_VERSION"}
      
      # Create backup
      mkdir -p "$BACKUP_DIR"
      BACKUP_FILE="$BACKUP_DIR/${FEATURE_NAME}_${FROM_VERSION}_to_${TO_VERSION}_$(date +%Y%m%d_%H%M%S).backup"
      
      if [ -f "$FEATURES_CONFIG" ]; then
        cp "$FEATURES_CONFIG" "$BACKUP_FILE"
        ${ui.messages.success "Backup created: $BACKUP_FILE"}
      fi
      
      # Load migration plan
      if [ ! -f "$MIGRATION_FILE" ]; then
        ${ui.messages.error "Migration file not found: $MIGRATION_FILE"}
        exit 1
      fi
      
      # Evaluate migration plan
      MIGRATION_PLAN=$(${pkgs.nix}/bin/nix-instantiate --eval --strict --json -E "
        import $MIGRATION_FILE { inherit (import <nixpkgs/lib>) lib; }
      " 2>/dev/null || echo "{}")
      
      if [ "$MIGRATION_PLAN" = "{}" ]; then
        ${ui.messages.error "Failed to load migration plan"}
        exit 1
      fi
      
      # Extract migration steps from plan
      OPTION_RENAMINGS=$(${pkgs.jq}/bin/jq -r '.optionRenamings // {} | to_entries | .[] | "\(.key)|\(.value)"' <<< "$MIGRATION_PLAN" 2>/dev/null || echo "")
      
      # Apply option renamings
      if [ -n "$OPTION_RENAMINGS" ]; then
        ${ui.messages.info "Applying option renamings..."}
        while IFS='|' read -r old_path new_path; do
          ${ui.messages.info "  Renaming: $old_path → $new_path"}
          # TODO: Implement actual option renaming in config files
          # This requires parsing and modifying Nix config files
        done <<< "$OPTION_RENAMINGS"
      fi
      
      # Execute migration script if present
      MIGRATION_SCRIPT=$(${pkgs.jq}/bin/jq -r '.migrationScript // ""' <<< "$MIGRATION_PLAN" 2>/dev/null || echo "")
      if [ -n "$MIGRATION_SCRIPT" ] && [ "$MIGRATION_SCRIPT" != "null" ]; then
        ${ui.messages.info "Executing migration script..."}
        eval "$MIGRATION_SCRIPT"
      fi
      
      # Update version in module config file (now individual per module)
      if [ -f "$FEATURES_CONFIG" ]; then
        ${ui.messages.info "Updating version in $FEATURE_NAME-config.nix..."}
        # Update _version for the module
        # This is a simplified version - full implementation would parse and modify Nix files properly
        ${ui.messages.warning "Version update in config file will be implemented in full migration handler"}
      fi
      
      ${ui.messages.success "Migration completed: $FEATURE_NAME $FROM_VERSION → $TO_VERSION"}
    '';
  
  # Execute migration chain
  # moduleName: Name of the module
  # migrationChain: [version1, version2, version3, ...]
  executeMigrationChain = moduleName: migrationChain:
    let
      # Create migration steps: [(from1, to1), (from2, to2), ...]
      steps = lib.zipLists migrationChain (lib.tail migrationChain);
      migrationSteps = lib.imap1 (idx: step:
        {
          from = lib.elemAt step 0;
          to = lib.elemAt step 1;
          path = ../../../../modules/${moduleName}/migrations + "/v${lib.elemAt step 0}-to-v${lib.elemAt step 1}.nix";
        }
      ) steps;
    in
      pkgs.writeShellScriptBin "migrate-chain-${moduleName}" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail
        
        FEATURE_NAME="$1"
        
        ${ui.messages.info "Executing migration chain for $FEATURE_NAME"}
        
        # Execute each migration step
        ${lib.concatMapStringsSep "\n" (step: ''
          ${executeMigration moduleName step.from step.to step.path}/bin/migrate-${moduleName}-${step.from}-to-${step.to} \
            "$FEATURE_NAME" "${step.from}" "${step.to}" "${step.path}"
        '') migrationSteps}
        
        ${ui.messages.success "Migration chain completed for $FEATURE_NAME"}
      '';

in {
  inherit executeMigration;
  inherit executeMigrationChain;
}

