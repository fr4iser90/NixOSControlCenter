{ pkgs, lib, ... }:

let
  schema = import ./config-schema.nix { inherit lib; };
  utils = import ./utils.nix { inherit lib; };
  detection = import ./config-detection.nix { inherit pkgs lib; };
  
  currentVersion = schema.currentVersion;
  minSupportedVersion = schema.minSupportedVersion;
  migrationPlans = schema.migrationPlans;
  migrationPaths = schema.migrationPaths;
  
  # Extract all supported versions dynamically from schema
  supportedVersions = lib.attrNames schema.schemas;
  
  # Convert migration paths to JSON for bash script
  migrationPathsJson = builtins.toJSON migrationPaths;
  
  # Convert migration plans to JSON for bash script
  migrationPlansJson = builtins.toJSON migrationPlans;
  
  # Helper .nix file that computes the migration chain (avoids nested ''...'' strings)
  findChainFile = pkgs.writeText "find-chain.nix" ''
    { migrationsPath, utilsPath, configVersion, currentVersion }:
    let
      lib = import <nixpkgs/lib>;
      utils = import utilsPath { inherit lib; };
      plans = utils.discoverMigrations migrationsPath;
      chain = utils.findMigrationChain plans configVersion currentVersion;
    in
      if chain != null then chain else []
  '';
  
  # Migration script that migrates old system-config.nix to new modular structure
  # NOTE: The old processStructure function was removed - migration now uses jq directly in bash
  migrateSystemConfig = pkgs.writeScriptBin "ncc-migrate-config" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    # Generic config directory - can be overridden via environment variable
    NIXOS_CONFIG_DIR="''${NIXOS_CONFIG_DIR:-/etc/nixos}"
    
    # All paths relative to NIXOS_CONFIG_DIR (no hardcoded paths)
    SYSTEM_CONFIG="$NIXOS_CONFIG_DIR/system-config.nix"
    CONFIGS_DIR="$NIXOS_CONFIG_DIR/configs"
    UTILS_PATH="$NIXOS_CONFIG_DIR/core/config/utils.nix"
    MIGRATIONS_PATH="$NIXOS_CONFIG_DIR/core/config/config-schema/migrations"
    
    # Set Nix and jq paths as bash variables (like in homelab-create.nix)
    NIX_BIN="${pkgs.nix}/bin/nix-instantiate"
    JQ_BIN="${pkgs.jq}/bin/jq"
    FIND_CHAIN_FILE="${findChainFile}"
    
    # Check if system-config.nix exists
    if [ ! -f "$SYSTEM_CONFIG" ]; then
      echo "ERROR: system-config.nix not found at $SYSTEM_CONFIG"
      exit 1
    fi
    
    # Load config to detect version
    # CRITICAL: Capture stderr to see actual errors, don't hide them!
    OLD_CONFIG_JSON=''$(${pkgs.nix}/bin/nix-instantiate --eval --strict --json -E "import $SYSTEM_CONFIG" 2>&1)
    NIX_EXIT_CODE=$?
    
    # Check if we got valid JSON (not an error message)
    if ! echo "$OLD_CONFIG_JSON" | "$JQ_BIN" . >/dev/null 2>&1; then
      # Not valid JSON - it's an error message from nix-instantiate
      echo "ERROR: Could not load system-config.nix"
      echo "       File: $SYSTEM_CONFIG"
      echo "       Current user: $(whoami)"
      echo "       File permissions: $(ls -l "$SYSTEM_CONFIG" 2>/dev/null || echo 'cannot check')"
      echo ""
      echo "       Nix error:"
      echo "$OLD_CONFIG_JSON" | head -10
      echo ""
      echo "       This migration requires sudo to read protected files."
      echo "       Run: sudo ncc-migrate-config"
      exit 1
    fi
    
    # Check if JSON is empty
    if [ "$OLD_CONFIG_JSON" = "{}" ] || [ "$OLD_CONFIG_JSON" = "null" ]; then
      echo "ERROR: system-config.nix loaded but is empty"
      echo "       File: $SYSTEM_CONFIG"
      exit 1
    fi
    
    # MODERN VERSION DETECTION: Use detectionPatterns from schemas via detection module
    CONFIG_VERSION=''$(${detection.detectConfigVersion}/bin/ncc-detect-version)
    
    # Get schema info (evaluated at build time, embedded in script)
    CURRENT_VERSION="${currentVersion}"
    MIN_SUPPORTED="${minSupportedVersion}"
    SUPPORTED_VERSIONS="${toString supportedVersions}"
    MIGRATION_PATHS='${migrationPathsJson}'
    MIGRATION_PLANS='${migrationPlansJson}'
    
    echo "INFO: Detected config version: $CONFIG_VERSION"
    
    # Check if version is supported
    VERSION_SUPPORTED=false
    for v in $SUPPORTED_VERSIONS; do
      if [ "$v" = "$CONFIG_VERSION" ]; then
        VERSION_SUPPORTED=true
        break
      fi
    done
    
    if [ "$VERSION_SUPPORTED" = "false" ]; then
      echo "WARNING: Config version $CONFIG_VERSION not recognized"
      echo "         Supported versions: $SUPPORTED_VERSIONS"
      echo "         Assuming v$MIN_SUPPORTED"
      CONFIG_VERSION="$MIN_SUPPORTED"
    fi
    
    # Check if already on current version
    if [ "$CONFIG_VERSION" = "$CURRENT_VERSION" ]; then
      echo "INFO: Config is already on version $CURRENT_VERSION, no migration needed"
      exit 0
    fi
    
    # Find migration chain (handles both direct and chain migrations)
    # Try direct migration first
    MIGRATION_TARGET=''$(echo "$MIGRATION_PATHS" | "$JQ_BIN" -r ".\"$CONFIG_VERSION\" // empty")
    
    # Prepare backup file name (before problematic if block)
    BACKUP_FILE_CHAIN="$SYSTEM_CONFIG.backup.''$(date +%Y%m%d_%H%M%S)"
    
    # If no direct migration, try to find chain migration
    if [ -z "$MIGRATION_TARGET" ] || [ "$MIGRATION_TARGET" = "null" ]; then
      # Use findMigrationChain to get full chain (v1→v2→v3→v4)
      # Call nix-instantiate on the prewritten helper .nix file instead of inline -E expression
      CHAIN_JSON=''$("$NIX_BIN" --eval --strict --json "$FIND_CHAIN_FILE" \
        --argstr migrationsPath "$MIGRATIONS_PATH" \
        --argstr utilsPath "$UTILS_PATH" \
        --argstr configVersion "$CONFIG_VERSION" \
        --argstr currentVersion "$CURRENT_VERSION" \
        2>/dev/null || echo "[]")
      
      if [ "$CHAIN_JSON" = "[]" ] || [ -z "$CHAIN_JSON" ]; then
        echo "ERROR: No migration path from version $CONFIG_VERSION to $CURRENT_VERSION"
        echo "       Supported versions: $SUPPORTED_VERSIONS"
        echo "       Current version: $CURRENT_VERSION"
        exit 1
      fi
      
      # Extract chain steps
      CHAIN_STEPS=''$(echo "$CHAIN_JSON" | "$JQ_BIN" -r ".[]")
      CHAIN_ARRAY=($CHAIN_STEPS)
      
      if [ ''${#CHAIN_ARRAY[@]} -lt 2 ]; then
        echo "ERROR: Invalid migration chain"
        exit 1
      fi
      
      echo "INFO: Detected config version: $CONFIG_VERSION"
      echo "INFO: Found migration chain (will migrate step by step)"
      echo "INFO: Starting chain migration..."
      CURRENT_STEP="$CONFIG_VERSION"
      
      # Create backup before chain migration
      mkdir -p "$CONFIGS_DIR"
      cp "$SYSTEM_CONFIG" "$BACKUP_FILE_CHAIN"
      echo "INFO: Backup created: $BACKUP_FILE_CHAIN"
      for i in ''$(seq 1 ''$((''${#CHAIN_ARRAY[@]} - 1))); do
        NEXT_STEP="''${CHAIN_ARRAY[$i]}"
        echo ""
        echo "INFO: Migrating step $i/''$((''${#CHAIN_ARRAY[@]} - 1)): v$CURRENT_STEP → v$NEXT_STEP"
        
        # Reload config for this step
        OLD_CONFIG_JSON=''$(${pkgs.nix}/bin/nix-instantiate --eval --strict --json -E "import $SYSTEM_CONFIG" 2>&1)
        
        # Check if we got valid JSON
        if ! echo "$OLD_CONFIG_JSON" | "$JQ_BIN" . >/dev/null 2>&1; then
          echo "ERROR: Could not reload config for step $CURRENT_STEP -> $NEXT_STEP"
          echo "       Error: $(echo "$OLD_CONFIG_JSON" | head -5)"
          exit 1
        fi
        
        if [ "$OLD_CONFIG_JSON" = "{}" ] || [ "$OLD_CONFIG_JSON" = "null" ]; then
          echo "ERROR: Config is empty after previous migration step"
          exit 1
        fi
        
        # Get migration plan for this step
        MIGRATION_PLAN=''$(echo "$MIGRATION_PLANS" | "$JQ_BIN" -r ".\"$CURRENT_STEP\".\"$NEXT_STEP\" // null")
        
        if [ "$MIGRATION_PLAN" = "null" ] || [ -z "$MIGRATION_PLAN" ]; then
          echo "ERROR: No migration plan found for $CURRENT_STEP -> $NEXT_STEP"
          exit 1
        fi
        
        # Execute single migration step (reuse migration logic)
        # Set target for this step
        STEP_TARGET="$NEXT_STEP"
        
        # Get fieldsToKeep
        FIELDS_TO_KEEP=''$(echo "$MIGRATION_PLAN" | "$JQ_BIN" -r '.fieldsToKeep // [] | .[]')
        
        # CRITICAL: Use temp file, only overwrite if successful
        TEMP_STEP_CONFIG=$(mktemp)
        FIELDS_EXTRACTED_STEP=0
        
        # Create minimal system-config.nix in temp file
        echo "{" > "$TEMP_STEP_CONFIG"
        echo "  configVersion = \"$STEP_TARGET\";" >> "$TEMP_STEP_CONFIG"
        echo "" >> "$TEMP_STEP_CONFIG"
        
        # Extract fieldsToKeep
        for field in $FIELDS_TO_KEEP; do
          if [[ "$field" == *"."* ]]; then
            FIELD_VALUE=''$(echo "$OLD_CONFIG_JSON" | "$JQ_BIN" -c ".$field // null")
            if [ "$FIELD_VALUE" != "null" ] && [ -n "$FIELD_VALUE" ]; then
              FIELD_ROOT=''$(echo "$field" | cut -d'.' -f1)
              echo "  $FIELD_ROOT = {" >> "$TEMP_STEP_CONFIG"
              echo "$FIELD_VALUE" | "$JQ_BIN" -r "to_entries[] | \"    \(.key) = \(.value | if type == \"string\" then \"\\\"\(.)\\\"\" elif type == \"boolean\" then . else . end);\"" >> "$TEMP_STEP_CONFIG"
              echo "  };" >> "$TEMP_STEP_CONFIG"
              FIELDS_EXTRACTED_STEP=$((FIELDS_EXTRACTED_STEP + 1))
            fi
          else
            FIELD_VALUE=''$(echo "$OLD_CONFIG_JSON" | "$JQ_BIN" -c ".$field // empty")
            if [ -n "$FIELD_VALUE" ] && [ "$FIELD_VALUE" != "null" ] && [ "$FIELD_VALUE" != "\"\"" ]; then
              # Format field value generically using jq with recursive solution
              # Supports arbitrary nesting depth
              echo "$OLD_CONFIG_JSON" | "$JQ_BIN" -r ".$field | 
                def formatNixValue(v; indent):
                  if v == null then \"null\"
                  elif v | type == \"string\" then \"\\\"\(v)\\\"\"
                  elif v | type == \"boolean\" then (if v then \"true\" else \"false\" end)
                  elif v | type == \"number\" then (v | tostring)
                  elif v | type == \"array\" then 
                    \"[ \" + (v | map(formatNixValue(.; indent)) | join(\", \")) + \" ]\"
                  elif v | type == \"object\" then
                    \"{\" + (
                      v | to_entries | map(
                        \"\\n\" + indent + \"  \(.key) = \" + formatNixValue(.value; indent + \"  \") + \";\"
                      ) | join(\"\")
                    ) + \"\\n\" + indent + \"}\"
                  else \"\\\"\(v)\\\"\" end;
                \"  $field = \" + formatNixValue(.; \"  \") + \";\"" >> "$TEMP_STEP_CONFIG"
              FIELDS_EXTRACTED_STEP=$((FIELDS_EXTRACTED_STEP + 1))
            fi
          fi
        done
        
        echo "}" >> "$TEMP_STEP_CONFIG"
        
        # Only overwrite if we extracted fields
        if [ "$FIELDS_EXTRACTED_STEP" -eq 0 ]; then
          echo "ERROR: Could not extract any fields in step $CURRENT_STEP -> $NEXT_STEP"
          rm -f "$TEMP_STEP_CONFIG"
          exit 1
        fi
        
        # CRITICAL: Process fieldsToMigrate BEFORE overwriting system-config.nix
        # This way if migration fails, the original file is still intact
        # With set -euo pipefail, script will exit on any error before mv
        FIELDS_TO_MIGRATE=''$(echo "$MIGRATION_PLAN" | "$JQ_BIN" -r '.fieldsToMigrate // {} | keys[]')
        
        for field_name in $FIELDS_TO_MIGRATE; do
          FIELD_PLAN=''$(echo "$MIGRATION_PLAN" | "$JQ_BIN" -r ".fieldsToMigrate.\"$field_name\"")
          TARGET_FILE=''$(echo "$FIELD_PLAN" | "$JQ_BIN" -r '.targetFile // empty' | sed 's|configs/||')
          
          if [ -z "$TARGET_FILE" ] || [ -f "$CONFIGS_DIR/$TARGET_FILE" ]; then
            continue
          fi
          
          FIELD_STRUCTURE=''$(echo "$FIELD_PLAN" | "$JQ_BIN" -c '.structure // {}')
          FIELD_MAPPINGS=''$(echo "$FIELD_PLAN" | "$JQ_BIN" -c '.fieldMappings // {}')
          
          MAPPED_CONFIG_JSON="$OLD_CONFIG_JSON"
          if echo "$FIELD_MAPPINGS" | "$JQ_BIN" -e 'keys | length > 0' >/dev/null 2>&1; then
            for mapping_entry in ''$(echo "$FIELD_MAPPINGS" | "$JQ_BIN" -c 'to_entries[]'); do
              OLD_PATH=''$(echo "$mapping_entry" | "$JQ_BIN" -r '.key')
              NEW_PATH=''$(echo "$mapping_entry" | "$JQ_BIN" -r '.value')
              MAPPED_CONFIG_JSON=''$(echo "$MAPPED_CONFIG_JSON" | "$JQ_BIN" -c --arg oldPath "$OLD_PATH" --arg newPath "$NEW_PATH" '
                if .[$oldPath] then .[$newPath] = .[$oldPath] | del(.[$oldPath]) else . end
              ')
            done
          fi
          
          NEW_CONFIG_NIX=''$(echo "$FIELD_STRUCTURE" | "$JQ_BIN" -r --argjson oldConfig "$MAPPED_CONFIG_JSON" '
            def getPathValue(path; config):
              reduce (path | split(".")) as $key (config;
                if . == null then null elif type == "object" then .[$key] else null end
              );
            def formatValue(value):
              if value == null or value == "" then "null"
              elif value | type == "string" then "\"\(value)\""
              elif value | type == "boolean" then value
              elif value | type == "number" then value
              elif value | type == "array" then "[ " + (value | map(formatValue) | join(", ")) + " ]"
              elif value | type == "object" then "{ " + (value | to_entries | map("\(.key) = \(.value | formatValue)") | join("; ")) + " }"
              else "\"\(value)\"" end;
            def processStructure(structure; oldConfig; indent):
              structure | to_entries | map(
                if .value | type == "string" then
                  (getPathValue(.value; oldConfig)) as $extracted |
                  if $extracted != null and $extracted != "" then "\(indent)\(.key) = \($extracted | formatValue);" else "" end
                elif .value | type == "object" then
                  (processStructure(.value; oldConfig; indent + "  ")) as $nested |
                  if $nested != "" then "\(indent)\(.key) = {\n\($nested)\n\(indent)};" else "" end
                else "" end
              ) | map(select(. != "")) | join("\n");
            processStructure(.; $oldConfig; "  ")
          ')
          
          if [ -n "$NEW_CONFIG_NIX" ]; then
            echo "{" > "$CONFIGS_DIR/$TARGET_FILE"
            echo "$NEW_CONFIG_NIX" >> "$CONFIGS_DIR/$TARGET_FILE"
            echo "}" >> "$CONFIGS_DIR/$TARGET_FILE"
          fi
        done
        
        # CRITICAL: Only overwrite system-config.nix AFTER all migrations succeeded
        # If we reach here, all migrations succeeded (set -e would have stopped script on error)
        mv "$TEMP_STEP_CONFIG" "$SYSTEM_CONFIG"
        
        CURRENT_STEP="$NEXT_STEP"
      done
      
      echo ""
      echo "SUCCESS: Chain migration completed successfully!"
      echo "INFO: Backup saved at: $BACKUP_FILE_CHAIN"
      exit 0
    fi
    
    echo "INFO: Detected config version: $CONFIG_VERSION"
    echo "INFO: Migrating to version: $MIGRATION_TARGET"
    echo "INFO: Starting migration from v$CONFIG_VERSION to v$MIGRATION_TARGET..."
    
    # Create configs directory
    mkdir -p "$CONFIGS_DIR"
    
    # Create backup
    BACKUP_FILE="$SYSTEM_CONFIG.backup.''$(date +%Y%m%d_%H%M%S)"
    if ! cp "$SYSTEM_CONFIG" "$BACKUP_FILE"; then
      echo "ERROR: Failed to create backup"
      exit 1
    fi
    echo "INFO: Backup created: $BACKUP_FILE"
    
    # Get migration plan from schema
    MIGRATION_PLAN=''$(echo "$MIGRATION_PLANS" | "$JQ_BIN" -r ".\"$CONFIG_VERSION\".\"$MIGRATION_TARGET\" // null")
    
    if [ "$MIGRATION_PLAN" = "null" ] || [ -z "$MIGRATION_PLAN" ]; then
      echo "ERROR: No migration plan found for $CONFIG_VERSION -> $MIGRATION_TARGET"
      echo "       Please add migration plan to schema!"
      exit 1
    fi
    
    echo "INFO: Loaded migration plan from schema"
    
    # Get fieldsToKeep from migration plan
    FIELDS_TO_KEEP=''$(echo "$MIGRATION_PLAN" | "$JQ_BIN" -r '.fieldsToKeep // [] | .[]')
    
    # CRITICAL: Use temp file, only overwrite if successful
    TEMP_CONFIG=$(mktemp)
    FIELDS_EXTRACTED=0
    
    # Create minimal system-config.nix in temp file using fieldsToKeep from schema
    # NOTE: We write configVersion first, but it doesn't count as extracted field
    echo "{" > "$TEMP_CONFIG"
    echo "  # Configuration Schema Version" >> "$TEMP_CONFIG"
    echo "  configVersion = \"$MIGRATION_TARGET\";" >> "$TEMP_CONFIG"
    echo "" >> "$TEMP_CONFIG"
    
    # Extract and add each field from fieldsToKeep
    for field in $FIELDS_TO_KEEP; do
      # Handle nested fields (e.g., system.channel)
      if [[ "$field" == *"."* ]]; then
        # Nested field - extract from JSON and format
        FIELD_VALUE=''$(echo "$OLD_CONFIG_JSON" | "$JQ_BIN" -c ".$field // null")
        if [ "$FIELD_VALUE" != "null" ] && [ -n "$FIELD_VALUE" ]; then
          # Format nested field (e.g., system = { channel = "..."; })
          FIELD_ROOT=''$(echo "$field" | cut -d'.' -f1)
          echo "  $FIELD_ROOT = {" >> "$TEMP_CONFIG"
          echo "$FIELD_VALUE" | "$JQ_BIN" -r "to_entries[] | \"    \(.key) = \(.value | if type == \"string\" then \"\\\"\(.)\\\"\" elif type == \"boolean\" then . else . end);\"" >> "$TEMP_CONFIG"
          echo "  };" >> "$TEMP_CONFIG"
          FIELDS_EXTRACTED=$((FIELDS_EXTRACTED + 1))
        fi
      else
        # Simple field - extract value and format generically
        FIELD_VALUE=''$(echo "$OLD_CONFIG_JSON" | "$JQ_BIN" -c ".$field // empty")
        if [ -n "$FIELD_VALUE" ] && [ "$FIELD_VALUE" != "null" ] && [ "$FIELD_VALUE" != "\"\"" ]; then
          # Format field value generically using jq with recursive solution
          # Supports arbitrary nesting depth
          echo "$OLD_CONFIG_JSON" | "$JQ_BIN" -r ".$field | 
            def formatNixValue(v; indent):
              if v == null then \"null\"
              elif v | type == \"string\" then \"\\\"\(v)\\\"\"
              elif v | type == \"boolean\" then (if v then \"true\" else \"false\" end)
              elif v | type == \"number\" then (v | tostring)
              elif v | type == \"array\" then 
                \"[ \" + (v | map(formatNixValue(.; indent)) | join(\", \")) + \" ]\"
              elif v | type == \"object\" then
                \"{\" + (
                  v | to_entries | map(
                    \"\\n\" + indent + \"  \(.key) = \" + formatNixValue(.value; indent + \"  \") + \";\"
                  ) | join(\"\")
                ) + \"\\n\" + indent + \"}\"
              else \"\\\"\(v)\\\"\" end;
            \"  $field = \" + formatNixValue(.; \"  \") + \";\"" >> "$TEMP_CONFIG"
          FIELDS_EXTRACTED=$((FIELDS_EXTRACTED + 1))
        fi
      fi
    done
    
    echo "}" >> "$TEMP_CONFIG"
    
    # CRITICAL: Only overwrite if we extracted fields
    # Check if temp file only has configVersion (should have at least 5 lines: {, comment, configVersion, empty line, })
    TEMP_LINE_COUNT=$(wc -l < "$TEMP_CONFIG" 2>/dev/null || echo "0")
    
    if [ "$FIELDS_EXTRACTED" -eq 0 ]; then
      FIELD_COUNT=''$(echo "$OLD_CONFIG_JSON" | "$JQ_BIN" 'keys | length' 2>/dev/null || echo "0")
      echo "ERROR: Could not extract any required fields from old config"
      echo "       This would result in an empty system-config.nix (only configVersion)"
      echo "       Migration ABORTED to prevent data loss"
      echo ""
      echo "       Debug info:"
      echo "       - Fields extracted: $FIELDS_EXTRACTED"
      echo "       - Temp file lines: $TEMP_LINE_COUNT (should be > 4)"
      echo "       - Old config had $FIELD_COUNT field(s)"
      echo "       - fieldsToKeep: $FIELDS_TO_KEEP"
      echo "       - Old config keys: $(echo "$OLD_CONFIG_JSON" | "$JQ_BIN" -c 'keys' 2>/dev/null | head -c 200 || echo 'ERROR reading JSON')"
      echo ""
      echo "       Possible causes:"
      echo "       1. jq extraction failed (check errors above)"
      echo "       2. Field names don't match (check fieldsToKeep in migration plan)"
      echo "       3. Old config structure is different than expected"
      echo ""
      rm -f "$TEMP_CONFIG"
      exit 1
    fi
    
    # Additional safety check: temp file should have more than just configVersion
    if [ "$TEMP_LINE_COUNT" -le 4 ]; then
      echo "ERROR: Temp file only contains configVersion, no other fields extracted"
      echo "       Migration ABORTED to prevent data loss"
      echo "       Temp file content:"
      cat "$TEMP_CONFIG"
      rm -f "$TEMP_CONFIG"
      exit 1
    fi
    
    echo "INFO: Created minimal system-config.nix using fieldsToKeep from schema"
    echo "INFO: Successfully extracted $FIELDS_EXTRACTED required field(s)"
    
    # CRITICAL: Process fieldsToMigrate BEFORE overwriting system-config.nix
    # This way if migration fails, the original file is still intact
    # With set -euo pipefail, script will exit on any error before mv
    FIELDS_TO_MIGRATE=''$(echo "$MIGRATION_PLAN" | "$JQ_BIN" -r '.fieldsToMigrate // {} | keys[]')
    
    # Migrate each field based on schema plan
    for field_name in $FIELDS_TO_MIGRATE; do
      FIELD_PLAN=''$(echo "$MIGRATION_PLAN" | "$JQ_BIN" -r ".fieldsToMigrate.\"$field_name\"")
      TARGET_FILE=''$(echo "$FIELD_PLAN" | "$JQ_BIN" -r '.targetFile // empty' | sed 's|configs/||')
      FIELD_STRUCTURE=''$(echo "$FIELD_PLAN" | "$JQ_BIN" -c '.structure // {}')
      FIELD_MAPPINGS=''$(echo "$FIELD_PLAN" | "$JQ_BIN" -c '.fieldMappings // {}')
      CONVERSION=''$(echo "$FIELD_PLAN" | "$JQ_BIN" -r '.conversion // empty')
      
      if [ -z "$TARGET_FILE" ]; then
        echo "WARNING: No targetFile for field $field_name, skipping"
        continue
      fi
      
      # Check if field exists in old config
      FIELD_EXISTS=false
      if echo "$FIELD_MAPPINGS" | "$JQ_BIN" -e 'keys | length > 0' >/dev/null 2>&1; then
        # Check if any mapped field exists
        for mapped_field in ''$(echo "$FIELD_MAPPINGS" | "$JQ_BIN" -r 'keys[]'); do
          if "$JQ_BIN" -e ".$mapped_field // empty | length > 0" <<< "$OLD_CONFIG_JSON" >/dev/null 2>&1; then
            FIELD_EXISTS=true
            break
          fi
        done
      fi
      
      if [ "$FIELD_EXISTS" = "false" ]; then
        # Check if original field exists
        if ! "$JQ_BIN" -e ".$field_name // empty | length > 0" <<< "$OLD_CONFIG_JSON" >/dev/null 2>&1; then
          echo "INFO: Field $field_name not found in old config, skipping"
          continue
        fi
      fi
      
      echo "INFO: Migrating field $field_name to $TARGET_FILE"
      
      # Apply field mappings first (e.g., hardware.memory -> hardware.ram)
      MAPPED_CONFIG_JSON="$OLD_CONFIG_JSON"
      if echo "$FIELD_MAPPINGS" | "$JQ_BIN" -e 'keys | length > 0' >/dev/null 2>&1; then
        for mapping_entry in ''$(echo "$FIELD_MAPPINGS" | "$JQ_BIN" -c 'to_entries[]'); do
          OLD_PATH=''$(echo "$mapping_entry" | "$JQ_BIN" -r '.key')
          NEW_PATH=''$(echo "$mapping_entry" | "$JQ_BIN" -r '.value')
          
          # Use jq to move the field
          MAPPED_CONFIG_JSON=''$(echo "$MAPPED_CONFIG_JSON" | "$JQ_BIN" -c --arg oldPath "$OLD_PATH" --arg newPath "$NEW_PATH" '
            if .[$oldPath] then
              .[$newPath] = .[$oldPath] |
              del(.[$oldPath])
            else .
            end
          ')
        done
      fi
      
      # Process structure recursively to extract values and generate Nix code
      # This is the core: walk through structure, extract values using paths, generate Nix
      NEW_CONFIG_NIX=''$(echo "$FIELD_STRUCTURE" | "$JQ_BIN" -r --argjson oldConfig "$MAPPED_CONFIG_JSON" '
        def getPathValue(path; config):
          reduce (path | split(".")) as $key (config;
            if . == null then null
            elif type == "object" then .[$key]
            else null
            end
          );
        
        def formatValue(value):
          if value == null or value == "" then "null"
          elif value | type == "string" then "\"\(value)\""
          elif value | type == "boolean" then value
          elif value | type == "number" then value
          elif value | type == "array" then 
            "[ " + (value | map(formatValue) | join(", ")) + " ]"
          elif value | type == "object" then
            "{ " + (value | to_entries | map("\(.key) = \(.value | formatValue)") | join("; ")) + " }"
          else "\"\(value)\""
          end;
        
        def processStructure(structure; oldConfig; indent):
          structure | to_entries | map(
            if .value | type == "string" then
              # Value is a path in old config - extract it
              (getPathValue(.value; oldConfig)) as $extracted |
              if $extracted != null and $extracted != "" then
                "\(indent)\(.key) = \($extracted | formatValue);"
              else
                ""
              end
            elif .value | type == "object" then
              # Nested structure - recurse
              (processStructure(.value; oldConfig; indent + "  ")) as $nested |
              if $nested != "" then
                "\(indent)\(.key) = {\n\($nested)\n\(indent)};"
              else
                ""
              end
            else
              ""
            end
          ) | map(select(. != "")) | join("\n");
        
        processStructure(.; $oldConfig; "  ")
      ')
      
      # Write config file
      if [ -n "$NEW_CONFIG_NIX" ]; then
        echo "{" > "$CONFIGS_DIR/$TARGET_FILE"
        echo "$NEW_CONFIG_NIX" >> "$CONFIGS_DIR/$TARGET_FILE"
        echo "}" >> "$CONFIGS_DIR/$TARGET_FILE"
        echo "INFO: Created $TARGET_FILE"
      fi
    done
    
    # CRITICAL: Only overwrite system-config.nix AFTER all migrations succeeded
    # If we reach here, all migrations succeeded (set -e would have stopped script on error)
    mv "$TEMP_CONFIG" "$SYSTEM_CONFIG"
    
    echo "SUCCESS: Migration completed successfully!"
    echo "INFO: Backup saved at: $BACKUP_FILE"
  '';

in {
  inherit migrateSystemConfig;
}

