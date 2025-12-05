{ pkgs, lib, ... }:

let
  migration = import ./config-migration.nix { inherit pkgs lib; };
  validator = import ./config-validator.nix { inherit pkgs lib; };
in

{
  # Main command: ncc-config-check
  # Validates config, attempts migration if needed, re-validates
  configCheck = pkgs.writeShellScriptBin "ncc-config-check" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    SYSTEM_CONFIG="/etc/nixos/system-config.nix"
    
    # Step 1: Validate config
    echo "Checking system configuration..."
    if ${validator.validateSystemConfig}/bin/ncc-validate-config 2>&1; then
      echo "✓ Configuration is valid"
      exit 0
    else
      VALIDATION_EXIT=$?
      if [ $VALIDATION_EXIT -eq 1 ]; then
        echo "⚠ Configuration validation found issues"
        echo "Attempting automatic migration..."
        
        # Step 2: Try migration
        if ${migration.migrateSystemConfig}/bin/ncc-migrate-config 2>&1; then
          echo "✓ Migration completed successfully"
          
          # Step 3: Re-validate after migration
          echo "Re-validating configuration..."
          if ${validator.validateSystemConfig}/bin/ncc-validate-config 2>&1; then
            echo "✓ Configuration is now valid"
            exit 0
          else
            echo "⚠ Configuration still has issues after migration"
            echo "   Manual intervention may be required"
            exit 1
          fi
        else
          echo "⚠ Migration failed or not needed"
          echo "   Configuration may need manual fixes"
          exit 1
        fi
      else
        # Validation failed with unexpected error
        echo "ERROR: Validation failed with unexpected error"
        exit 1
      fi
    fi
  '';
}

