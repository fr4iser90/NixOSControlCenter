{ pkgs, lib, getModuleApi, backupHelpers, ... }:

let
  schema = import ./schema.nix { inherit lib; };
  utils = import ./utils.nix { inherit lib; };
  detection = import ./detection.nix { inherit pkgs lib; };
  formatter = getModuleApi "cli-formatter";
  
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
    
    # Parse arguments for verbose mode
    VERBOSE=false
    for arg in "$@"; do
      case "$arg" in
        --verbose|--debug|-v)
          VERBOSE=true
          ;;
      esac
    done
    
    # Generic config directory - can be overridden via environment variable
    NIXOS_CONFIG_DIR="''${NIXOS_CONFIG_DIR:-/etc/nixos}"
    
    # All paths relative to NIXOS_CONFIG_DIR (no hardcoded paths)
    SYSTEM_CONFIG="$NIXOS_CONFIG_DIR/system-config.nix"
    CONFIGS_DIR="$NIXOS_CONFIG_DIR/systemConfig"
    UTILS_PATH="$NIXOS_CONFIG_DIR/core/management/system-manager/lib/utils-config-migration.nix"
    MIGRATIONS_PATH="$NIXOS_CONFIG_DIR/core/management/system-manager/components/config-migration/schema/migrations"
    
    # Set Nix and jq paths as bash variables (like in homelab-create.nix)
    NIX_BIN="${pkgs.nix}/bin/nix-instantiate"
    JQ_BIN="${pkgs.jq}/bin/jq"
    FIND_CHAIN_FILE="${findChainFile}"
    
    # PRE-CHECK: If already at current schema version, only clean stale artifacts
    # Just clean up stale files from incomplete previous migrations
    SM_CONFIG="$CONFIGS_DIR/core/management/system-manager/config.nix"
    MONOLITH_FILE="$NIXOS_CONFIG_DIR/systemConfig.nix"
    CURRENT_VERSION_PRE="${currentVersion}"
    DETECTED_PRE=""
    if [ -f "$MONOLITH_FILE" ] || [ -f "$SM_CONFIG" ] || [ -f "$SYSTEM_CONFIG" ]; then
      DETECTED_PRE=''$(${detection.detectConfigVersion}/bin/ncc-detect-version 2>/dev/null || true)
    fi
    if [ "$DETECTED_PRE" = "$CURRENT_VERSION_PRE" ]; then
      if [ -f "$SYSTEM_CONFIG" ]; then
        ${formatter.messages.info "Removing stale system-config.nix (v2 already active)"}
        rm -f "$SYSTEM_CONFIG"
      fi
      for agg in \
        "$CONFIGS_DIR/core/config.nix" \
        "$CONFIGS_DIR/core/base/config.nix" \
        "$CONFIGS_DIR/core/management/config.nix" \
        "$CONFIGS_DIR/modules/config.nix" \
        "$CONFIGS_DIR/modules/infrastructure/config.nix" \
        "$CONFIGS_DIR/modules/security/config.nix" \
        "$CONFIGS_DIR/modules/specialized/config.nix" \
        "$CONFIGS_DIR/modules/system/config.nix"; do
        if [ -f "$agg" ]; then
          rm -f "$agg"
          if [ "$VERBOSE" = "true" ]; then
            ${formatter.messages.info "Removed stale aggregator config: $agg"}
          fi
        fi
      done
      exit 0
    fi

    # v1→v2 in-place bump when already on split layout without legacy system-config.nix
    if [ "$DETECTED_PRE" = "1.0" ] && [ ! -f "$SYSTEM_CONFIG" ] && [ -f "$SM_CONFIG" ]; then
      ${formatter.messages.info "Bumping split config from v1.0 → v2.0 (layout=split)"}
      if grep -q "configVersion" "$SM_CONFIG"; then
        sed -i 's/configVersion = "[^"]*"/configVersion = "2.0"/' "$SM_CONFIG"
      else
        sed -i '0,/{/s/{/{\n  configVersion = "2.0";/' "$SM_CONFIG"
      fi
      if grep -qE 'layout\s*=' "$SM_CONFIG"; then
        sed -i 's/layout = "[^"]*"/layout = "split"/' "$SM_CONFIG"
      else
        sed -i '0,/{/s/{/{\n  layout = "split";/' "$SM_CONFIG"
      fi
      exit 0
    fi
    
    # Check if system-config.nix exists
    if [ ! -f "$SYSTEM_CONFIG" ]; then
      ${formatter.messages.error "system-config.nix not found at $SYSTEM_CONFIG"}
      exit 1
    fi
    
    # Load config to detect version
    # CRITICAL: Capture stderr to see actual errors, don't hide them!
    OLD_CONFIG_JSON=''$(${pkgs.nix}/bin/nix-instantiate --eval --strict --json -E "import $SYSTEM_CONFIG" 2>&1)
    NIX_EXIT_CODE=$?
    
    # Check if we got valid JSON (not an error message)
    if ! echo "$OLD_CONFIG_JSON" | "$JQ_BIN" . >/dev/null 2>&1; then
      # Not valid JSON - it's an error message from nix-instantiate
      ${formatter.messages.error "Could not load system-config.nix"}
      if [ "$VERBOSE" = "true" ]; then
        ${formatter.messages.info "File: $SYSTEM_CONFIG"}
        CURRENT_USER=$(whoami)
        FILE_PERMS=$(ls -l "$SYSTEM_CONFIG" 2>/dev/null || echo 'cannot check')
        ${formatter.messages.info "Current user: $CURRENT_USER"}
        ${formatter.messages.info "File permissions: $FILE_PERMS"}
        ${formatter.text.newline}
        ${formatter.messages.info "Nix error:"}
        echo "$OLD_CONFIG_JSON" | head -10
        ${formatter.text.newline}
      fi
      ${formatter.messages.info "This migration requires sudo to read protected files."}
      ${formatter.messages.info "Run: sudo ncc-migrate-config"}
      exit 1
    fi
    
    # Check if JSON is empty
    if [ "$OLD_CONFIG_JSON" = "{}" ] || [ "$OLD_CONFIG_JSON" = "null" ]; then
      ${formatter.messages.error "system-config.nix loaded but is empty"}
      if [ "$VERBOSE" = "true" ]; then
        ${formatter.messages.info "File: $SYSTEM_CONFIG"}
      fi
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
    
    if [ "$VERBOSE" = "true" ]; then
      ${formatter.messages.info "Detected config version: $CONFIG_VERSION"}
    fi
    
    # Check if version is supported
    VERSION_SUPPORTED=false
    for v in $SUPPORTED_VERSIONS; do
      if [ "$v" = "$CONFIG_VERSION" ]; then
        VERSION_SUPPORTED=true
        break
      fi
    done
    
    if [ "$VERSION_SUPPORTED" = "false" ]; then
      if [ "$VERBOSE" = "true" ]; then
        ${formatter.messages.warning "Config version $CONFIG_VERSION not recognized"}
        ${formatter.messages.info "Supported versions: $SUPPORTED_VERSIONS"}
        ${formatter.messages.info "Assuming v$MIN_SUPPORTED"}
      fi
      CONFIG_VERSION="$MIN_SUPPORTED"
    fi
    
    # Check if already on current version
    if [ "$CONFIG_VERSION" = "$CURRENT_VERSION" ]; then
      if [ "$VERBOSE" = "true" ]; then
        ${formatter.messages.info "Config is already on version $CURRENT_VERSION, no migration needed"}
      fi
      exit 0
    fi
    
    # Find migration chain (handles both direct and chain migrations)
    # Try direct migration first
    MIGRATION_TARGET=''$(echo "$MIGRATION_PATHS" | "$JQ_BIN" -r ".\"$CONFIG_VERSION\" // empty")
    
    # Prepare backup file name (before problematic if block)
    # Use centralized backup helper
    BACKUP_FILE_CHAIN=$(${backupHelpers.backupConfigFile "$SYSTEM_CONFIG" "chain-migration"})
    if [ -z "$BACKUP_FILE_CHAIN" ]; then
      ${formatter.messages.error "Failed to create backup"}
      exit 1
    fi
    
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
        ${formatter.messages.error "No migration path from version $CONFIG_VERSION to $CURRENT_VERSION"}
        if [ "$VERBOSE" = "true" ]; then
          ${formatter.messages.info "Supported versions: $SUPPORTED_VERSIONS"}
          ${formatter.messages.info "Current version: $CURRENT_VERSION"}
        fi
        exit 1
      fi
      
      # Extract chain steps
      CHAIN_STEPS=''$(echo "$CHAIN_JSON" | "$JQ_BIN" -r ".[]")
      CHAIN_ARRAY=($CHAIN_STEPS)
      
      if [ ''${#CHAIN_ARRAY[@]} -lt 2 ]; then
        ${formatter.messages.error "Invalid migration chain"}
        exit 1
      fi
      
      if [ "$VERBOSE" = "true" ]; then
        ${formatter.messages.info "Detected config version: $CONFIG_VERSION"}
        ${formatter.messages.info "Found migration chain (will migrate step by step)"}
        ${formatter.messages.info "Starting chain migration..."}
      fi
      CURRENT_STEP="$CONFIG_VERSION"
      
      # Backup already created above
      mkdir -p "$CONFIGS_DIR"
      if [ "$VERBOSE" = "true" ]; then
        ${formatter.messages.info "Backup created: $BACKUP_FILE_CHAIN"}
      fi
      for i in ''$(seq 1 ''$((''${#CHAIN_ARRAY[@]} - 1))); do
        NEXT_STEP="''${CHAIN_ARRAY[$i]}"
        if [ "$VERBOSE" = "true" ]; then
          ${formatter.text.newline}
          CHAIN_LENGTH=$((''${#CHAIN_ARRAY[@]} - 1))
          ${formatter.messages.info "Migrating step $i/$CHAIN_LENGTH: v$CURRENT_STEP → v$NEXT_STEP"}
        fi
        
        # Reload config for this step
        OLD_CONFIG_JSON=''$(${pkgs.nix}/bin/nix-instantiate --eval --strict --json -E "import $SYSTEM_CONFIG" 2>&1)
        
        # Check if we got valid JSON
        if ! echo "$OLD_CONFIG_JSON" | "$JQ_BIN" . >/dev/null 2>&1; then
          ${formatter.messages.error "Could not reload config for step $CURRENT_STEP -> $NEXT_STEP"}
          if [ "$VERBOSE" = "true" ]; then
            ERROR_MSG=$(echo "$OLD_CONFIG_JSON" | head -5)
            ${formatter.messages.info "Error: $ERROR_MSG"}
          fi
          exit 1
        fi
        
        if [ "$OLD_CONFIG_JSON" = "{}" ] || [ "$OLD_CONFIG_JSON" = "null" ]; then
          ${formatter.messages.error "Config is empty after previous migration step"}
          exit 1
        fi
        
        # Get migration plan for this step
        MIGRATION_PLAN=''$(echo "$MIGRATION_PLANS" | "$JQ_BIN" -r ".\"$CURRENT_STEP\".\"$NEXT_STEP\" // null")
        
        if [ "$MIGRATION_PLAN" = "null" ] || [ -z "$MIGRATION_PLAN" ]; then
          ${formatter.messages.error "No migration plan found for $CURRENT_STEP -> $NEXT_STEP"}
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
          ${formatter.messages.error "Could not extract any fields in step $CURRENT_STEP -> $NEXT_STEP"}
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
          RAW_SOURCE=''$(echo "$FIELD_PLAN" | "$JQ_BIN" -r '.rawSource // empty')
          RAW_UNWRAP=''$(echo "$FIELD_PLAN" | "$JQ_BIN" -r '.rawUnwrap // false')
          
          if [ -n "$RAW_SOURCE" ]; then
            RAW_VALUE=''$(echo "$OLD_CONFIG_JSON" | "$JQ_BIN" -c "$RAW_SOURCE" 2>/dev/null || echo "null")
            if [ -n "$RAW_VALUE" ] && [ "$RAW_VALUE" != "null" ]; then
              if [ "$RAW_UNWRAP" = "true" ]; then
                NEW_CONFIG_NIX=''$(echo "$RAW_VALUE" | "$JQ_BIN" -r --arg key "$field_name" '
                  def fmt(v):
                    if v == null then "null"
                    elif v | type == "string" then "\"\(v)\""
                    elif v | type == "boolean" then (if v then "true" else "false" end)
                    elif v | type == "number" then (v | tostring)
                    elif v | type == "array" then "[ " + (v | map(fmt(.)) | join(" ")) + " ]"
                    elif v | type == "object" then
                      "{\n" + (v | to_entries | map("  \(.key) = \(fmt(.value));") | join("\n")) + "\n}"
                    else "\"\(v)\"" end;
                  to_entries | map("\(.key) = \(fmt(.value));") | join("\n")
                ')
              else
                NEW_CONFIG_NIX=''$(echo "$RAW_VALUE" | "$JQ_BIN" -r --arg key "$field_name" '
                  def fmt(v):
                    if v == null then "null"
                    elif v | type == "string" then "\"\(v)\""
                    elif v | type == "boolean" then (if v then "true" else "false" end)
                    elif v | type == "number" then (v | tostring)
                    elif v | type == "array" then "[ " + (v | map(fmt(.)) | join(" ")) + " ]"
                    elif v | type == "object" then
                      "{\n" + (v | to_entries | map("  \(.key) = \(fmt(.value));") | join("\n")) + "\n}"
                    else "\"\(v)\"" end;
                  "\($key) = \(fmt(.));"
                ')
              fi
            fi
          else
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
                elif value | type == "array" then "[ " + (value | map(formatValue(.)) | join(" ")) + " ]"
                elif value | type == "object" then "{ " + (value | to_entries | map("\(.key) = \(formatValue(.value))") | join("; ")) + " }"
                else "\"\(value)\"" end;
              def processStructure(structure; oldConfig; indent):
                structure | to_entries | map(
                  if .value | type == "string" then
                    (getPathValue(.value; oldConfig)) as $extracted |
                    if $extracted != null and $extracted != "" then "\(indent)\(.key) = \(formatValue($extracted));" else "" end
                  elif .value | type == "object" then
                    (processStructure(.value; oldConfig; indent + "  ")) as $nested |
                    if $nested != "" then "\(indent)\(.key) = {\n\($nested)\n\(indent)};" else "" end
                  else "" end
                ) | map(select(. != "")) | join("\n");
              processStructure(.; $oldConfig; "  ")
            ')
          fi
          
          if [ -n "$NEW_CONFIG_NIX" ]; then
            mkdir -p "$(dirname "$CONFIGS_DIR/$TARGET_FILE")"
            if [ ! -f "$CONFIGS_DIR/$TARGET_FILE" ]; then
              echo "{" > "$CONFIGS_DIR/$TARGET_FILE"
              echo "$NEW_CONFIG_NIX" >> "$CONFIGS_DIR/$TARGET_FILE"
              echo "}" >> "$CONFIGS_DIR/$TARGET_FILE"
            elif [ "$(tr -d ' \t\n\r' < "$CONFIGS_DIR/$TARGET_FILE" 2>/dev/null)" = "{}" ]; then
              echo "{" > "$CONFIGS_DIR/$TARGET_FILE"
              echo "$NEW_CONFIG_NIX" >> "$CONFIGS_DIR/$TARGET_FILE"
              echo "}" >> "$CONFIGS_DIR/$TARGET_FILE"
            fi
          fi
        done
        
        # CRITICAL: All migration steps succeeded
        # Delete old system-config.nix (already backed up at start of chain)
        rm -f "$SYSTEM_CONFIG" "$TEMP_STEP_CONFIG"
        
        CURRENT_STEP="$NEXT_STEP"
      done
      
      if [ "$VERBOSE" = "true" ]; then
        ${formatter.text.newline}
      fi
      exit 0
    fi
    
    if [ "$VERBOSE" = "true" ]; then
      ${formatter.messages.info "Detected config version: $CONFIG_VERSION"}
      ${formatter.messages.info "Migrating to version: $MIGRATION_TARGET"}
      ${formatter.messages.info "Starting migration from v$CONFIG_VERSION to v$MIGRATION_TARGET..."}
    fi
    
    # Create configs directory
    mkdir -p "$CONFIGS_DIR"
    
    # Create backup using centralized backup helper
    BACKUP_FILE=$(${backupHelpers.backupConfigFile "$SYSTEM_CONFIG" "migration"})
    if [ -z "$BACKUP_FILE" ]; then
      ${formatter.messages.error "Failed to create backup"}
      exit 1
    fi
    if [ "$VERBOSE" = "true" ]; then
      ${formatter.messages.info "Backup created: $BACKUP_FILE"}
    fi
    
    # Get migration plan from schema
    MIGRATION_PLAN=''$(echo "$MIGRATION_PLANS" | "$JQ_BIN" -r ".\"$CONFIG_VERSION\".\"$MIGRATION_TARGET\" // null")
    
    if [ "$MIGRATION_PLAN" = "null" ] || [ -z "$MIGRATION_PLAN" ]; then
      ${formatter.messages.error "No migration plan found for $CONFIG_VERSION -> $MIGRATION_TARGET"}
      if [ "$VERBOSE" = "true" ]; then
        ${formatter.messages.info "Please add migration plan to schema!"}
      fi
      exit 1
    fi
    
    if [ "$VERBOSE" = "true" ]; then
      ${formatter.messages.info "Loaded migration plan from schema"}
    fi
    
    # v0→v1 migration: ALL fields go to systemConfig/ subdirectory configs
    # No fields are kept in system-config.nix - it gets deleted after migration
    
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
        if [ "$VERBOSE" = "true" ]; then
          ${formatter.messages.warning "No targetFile for field $field_name, skipping"}
        fi
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
          if [ "$VERBOSE" = "true" ]; then
            ${formatter.messages.info "Field $field_name not found in old config, skipping"}
          fi
          continue
        fi
      fi
      
      if [ "$VERBOSE" = "true" ]; then
        ${formatter.messages.info "Migrating field $field_name to $TARGET_FILE"}
      fi
      
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
      
      # Handle rawSource (dynamic keys, e.g. users, features)
      RAW_SOURCE=''$(echo "$FIELD_PLAN" | "$JQ_BIN" -r '.rawSource // empty')
      RAW_UNWRAP=''$(echo "$FIELD_PLAN" | "$JQ_BIN" -r '.rawUnwrap // false')
      
      if [ -n "$RAW_SOURCE" ]; then
        RAW_VALUE=''$(echo "$OLD_CONFIG_JSON" | "$JQ_BIN" -c "$RAW_SOURCE" 2>/dev/null || echo "null")
        if [ -n "$RAW_VALUE" ] && [ "$RAW_VALUE" != "null" ]; then
          if [ "$RAW_UNWRAP" = "true" ]; then
            NEW_CONFIG_NIX=''$(echo "$RAW_VALUE" | "$JQ_BIN" -r --arg key "$field_name" '
              def fmt(v):
                if v == null then "null"
                elif v | type == "string" then "\"\(v)\""
                elif v | type == "boolean" then (if v then "true" else "false" end)
                elif v | type == "number" then (v | tostring)
                elif v | type == "array" then "[ " + (v | map(fmt(.)) | join(" ")) + " ]"
                elif v | type == "object" then
                  "{\n" + (v | to_entries | map("  \(.key) = \(fmt(.value));") | join("\n")) + "\n}"
                else "\"\(v)\"" end;
              to_entries | map("\(.key) = \(fmt(.value));") | join("\n")
            ')
          else
            NEW_CONFIG_NIX=''$(echo "$RAW_VALUE" | "$JQ_BIN" -r --arg key "$field_name" '
              def fmt(v):
                if v == null then "null"
                elif v | type == "string" then "\"\(v)\""
                elif v | type == "boolean" then (if v then "true" else "false" end)
                elif v | type == "number" then (v | tostring)
                elif v | type == "array" then "[ " + (v | map(fmt(.)) | join(" ")) + " ]"
                elif v | type == "object" then
                  "{\n" + (v | to_entries | map("  \(.key) = \(fmt(.value));") | join("\n")) + "\n}"
                else "\"\(v)\"" end;
              "\($key) = \(fmt(.));"
            ')
          fi
        fi
      else
        # Process structure recursively to extract values and generate Nix code
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
              "[ " + (value | map(formatValue(.)) | join(" ")) + " ]"
            elif value | type == "object" then
              "{ " + (value | to_entries | map("\(.key) = \(formatValue(.value))") | join("; ")) + " }"
            else "\"\(value)\""
            end;
          
          def processStructure(structure; oldConfig; indent):
            structure | to_entries | map(
              if .value | type == "string" then
                (getPathValue(.value; oldConfig)) as $extracted |
                if $extracted != null and $extracted != "" then
                  "\(indent)\(.key) = \(formatValue($extracted));"
                else
                  ""
                end
              elif .value | type == "object" then
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
      fi
      
      # Write config file
      # CRITICAL: Only create if file doesn't exist or is empty placeholder
      if [ -n "$NEW_CONFIG_NIX" ]; then
        mkdir -p "$(dirname "$CONFIGS_DIR/$TARGET_FILE")"
        if [ ! -f "$CONFIGS_DIR/$TARGET_FILE" ]; then
          echo "{" > "$CONFIGS_DIR/$TARGET_FILE"
          echo "$NEW_CONFIG_NIX" >> "$CONFIGS_DIR/$TARGET_FILE"
          echo "}" >> "$CONFIGS_DIR/$TARGET_FILE"
          if [ "$VERBOSE" = "true" ]; then
            ${formatter.messages.info "Created $TARGET_FILE"}
          fi
        elif [ "$(tr -d ' \t\n\r' < "$CONFIGS_DIR/$TARGET_FILE" 2>/dev/null)" = "{}" ]; then
          # File exists but is empty/placeholder — overwrite with migrated data
          echo "{" > "$CONFIGS_DIR/$TARGET_FILE"
          echo "$NEW_CONFIG_NIX" >> "$CONFIGS_DIR/$TARGET_FILE"
          echo "}" >> "$CONFIGS_DIR/$TARGET_FILE"
          if [ "$VERBOSE" = "true" ]; then
            ${formatter.messages.info "Overwrote empty placeholder $TARGET_FILE"}
          fi
        else
          if [ "$VERBOSE" = "true" ]; then
            ${formatter.messages.info "$TARGET_FILE already exists, skipping (preserving user config)"}
          fi
        fi
      fi
    done
    
    # CRITICAL: All migrations succeeded - now delete old system-config.nix
    # It's been backed up to /var/backup/nixos/ already
    # v1 uses modular systemConfig/ directory as the only entry point
    rm -f "$SYSTEM_CONFIG"
    
    # Clean up unnecessary aggregator configs (intermediate-level config.nix)
    # These duplicate what the leaf configs already define
    for agg in \
      "$CONFIGS_DIR/core/base/config.nix" \
      "$CONFIGS_DIR/core/management/config.nix" \
      "$CONFIGS_DIR/core/config.nix" \
      "$CONFIGS_DIR/modules/infrastructure/config.nix" \
      "$CONFIGS_DIR/modules/security/config.nix" \
      "$CONFIGS_DIR/modules/specialized/config.nix" \
      "$CONFIGS_DIR/modules/system/config.nix" \
      "$CONFIGS_DIR/modules/config.nix"; do
      if [ -f "$agg" ]; then
        rm -f "$agg"
        if [ "$VERBOSE" = "true" ]; then
          ${formatter.messages.info "Removed aggregator config: $agg"}
        fi
      fi
    done
    
    # Add configVersion to system-manager config (the canonical version location)
    SM_CONFIG="$CONFIGS_DIR/core/management/system-manager/config.nix"
    if [ -f "$SM_CONFIG" ]; then
      if ! grep -q "configVersion" "$SM_CONFIG" 2>/dev/null; then
        # Inject configVersion as the first field
        sed -i '1a\  configVersion = "'"$MIGRATION_TARGET"'";' "$SM_CONFIG"
      fi
    else
      # Create system-manager config with configVersion
      mkdir -p "$(dirname "$SM_CONFIG")"
      echo "{" > "$SM_CONFIG"
      echo "  configVersion = \"$MIGRATION_TARGET\";" >> "$SM_CONFIG"
      echo "}" >> "$SM_CONFIG"
    fi
    
    if [ "$VERBOSE" = "true" ]; then
      ${formatter.messages.info "Old system-config.nix backed up and removed"}
      ${formatter.messages.info "configVersion set in system-manager config"}
    fi
  '';

in {
  inherit migrateSystemConfig;
}
