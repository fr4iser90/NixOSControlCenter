{ pkgs, lib, ... }:

let
  # Migration script that migrates old system-config.nix to new modular structure
  migrateSystemConfig = pkgs.writeShellScriptBin "ncc-migrate-config" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    
    SYSTEM_CONFIG="/etc/nixos/system-config.nix"
    CONFIGS_DIR="/etc/nixos/configs"
    
    # Check if system-config.nix exists
    if [ ! -f "$SYSTEM_CONFIG" ]; then
      echo "ERROR: system-config.nix not found at $SYSTEM_CONFIG"
      exit 1
    fi
    
    # Check if already migrated (configs directory exists with files)
    if [ -d "$CONFIGS_DIR" ] && [ -n "$(ls -A "$CONFIGS_DIR"/*.nix 2>/dev/null)" ]; then
      echo "INFO: Already migrated (configs/ directory exists with files)"
      exit 0
    fi
    
    # Check if old structure (more than 20 lines or has non-critical values)
    LINE_COUNT=$(wc -l < "$SYSTEM_CONFIG" 2>/dev/null || echo "0")
    HAS_OLD_STRUCTURE=false
    
    if [ "$LINE_COUNT" -gt 20 ]; then
      HAS_OLD_STRUCTURE=true
    elif grep -q "desktop = {" "$SYSTEM_CONFIG" 2>/dev/null || \
         grep -q "hardware = {" "$SYSTEM_CONFIG" 2>/dev/null || \
         grep -q "features = {" "$SYSTEM_CONFIG" 2>/dev/null || \
         grep -q "packageModules = " "$SYSTEM_CONFIG" 2>/dev/null; then
      HAS_OLD_STRUCTURE=true
    fi
    
    if [ "$HAS_OLD_STRUCTURE" = "false" ]; then
      echo "INFO: system-config.nix is already minimal, no migration needed"
      exit 0
    fi
    
    echo "INFO: Old structure detected, starting migration..."
    
    # Create backup
    BACKUP_FILE="$SYSTEM_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    if ! cp "$SYSTEM_CONFIG" "$BACKUP_FILE"; then
      echo "ERROR: Failed to create backup"
      exit 1
    fi
    echo "INFO: Backup created: $BACKUP_FILE"
    
    # Create configs directory
    mkdir -p "$CONFIGS_DIR"
    
    # Load old config with nix-instantiate
    OLD_CONFIG_JSON=$(${pkgs.nix}/bin/nix-instantiate --eval --strict --json -E "import $SYSTEM_CONFIG" 2>/dev/null || echo "{}")
    
    if [ "$OLD_CONFIG_JSON" = "{}" ]; then
      echo "ERROR: Could not load old system-config.nix"
      exit 1
    fi
    
    # Extract critical values for minimal system-config.nix
    SYSTEM_TYPE=$(${pkgs.jq}/bin/jq -r '.systemType // "desktop"' <<< "$OLD_CONFIG_JSON")
    HOSTNAME=$(${pkgs.jq}/bin/jq -r '.hostName // "'"$(hostname)"'"' <<< "$OLD_CONFIG_JSON")
    CHANNEL=$(${pkgs.jq}/bin/jq -r '.system.channel // "stable"' <<< "$OLD_CONFIG_JSON")
    BOOTLOADER=$(${pkgs.jq}/bin/jq -r '.system.bootloader // "systemd-boot"' <<< "$OLD_CONFIG_JSON")
    ALLOW_UNFREE=$(${pkgs.jq}/bin/jq -r '.allowUnfree // true' <<< "$OLD_CONFIG_JSON")
    TIMEZONE=$(${pkgs.jq}/bin/jq -r '.timeZone // "Europe/Berlin"' <<< "$OLD_CONFIG_JSON")
    
    # Extract users block (complex, extract from file directly)
    USERS_BLOCK=""
    if grep -q "users = {" "$SYSTEM_CONFIG" 2>/dev/null; then
      USERS_BLOCK=$(awk '/users = {/,/^  };/' "$SYSTEM_CONFIG" | sed '1d;$d' | sed 's/^/    /' || echo "")
    fi
    
    if [ -z "$USERS_BLOCK" ]; then
      USERS_BLOCK="    # Users will be added later"
    fi
    
    # Create minimal system-config.nix
    cat > "$SYSTEM_CONFIG" <<EOF
{
  # System Identity
  systemType = "$SYSTEM_TYPE";
  hostName = "$HOSTNAME";
  
  # System Version
  system = {
    channel = "$CHANNEL";
    bootloader = "$BOOTLOADER";
  };
  
  # Nix Config
  allowUnfree = $ALLOW_UNFREE;
  
  # User Management
  users = {
$USERS_BLOCK
  };
  
  # TimeZone
  timeZone = "$TIMEZONE";
}
EOF
    
    echo "INFO: Created minimal system-config.nix"
    
    # Create desktop-config.nix if desktop exists
    if ${pkgs.jq}/bin/jq -e '.desktop // empty | length > 0' <<< "$OLD_CONFIG_JSON" >/dev/null 2>&1; then
      ENABLE=$(${pkgs.jq}/bin/jq -r '.desktop.enable // false' <<< "$OLD_CONFIG_JSON")
      ENV=$(${pkgs.jq}/bin/jq -r '.desktop.environment // "plasma"' <<< "$OLD_CONFIG_JSON")
      MANAGER=$(${pkgs.jq}/bin/jq -r '.desktop.display.manager // "sddm"' <<< "$OLD_CONFIG_JSON")
      SERVER=$(${pkgs.jq}/bin/jq -r '.desktop.display.server // "wayland"' <<< "$OLD_CONFIG_JSON")
      SESSION=$(${pkgs.jq}/bin/jq -r '.desktop.display.session // "plasma"' <<< "$OLD_CONFIG_JSON")
      DARK=$(${pkgs.jq}/bin/jq -r '.desktop.theme.dark // true' <<< "$OLD_CONFIG_JSON")
      AUDIO=$(${pkgs.jq}/bin/jq -r '.desktop.audio // "pipewire"' <<< "$OLD_CONFIG_JSON")
      
      cat > "$CONFIGS_DIR/desktop-config.nix" <<DESKTOPEOF
{
  # Desktop Environment
  desktop = {
    enable = $ENABLE;
    environment = "$ENV";
    display = {
      manager = "$MANAGER";
      server = "$SERVER";
      session = "$SESSION";
    };
    theme = {
      dark = $DARK;
    };
    audio = "$AUDIO";
  };
}
DESKTOPEOF
      echo "INFO: Created desktop-config.nix"
    fi
    
    # Create localization-config.nix if locales/keyboard exists
    if ${pkgs.jq}/bin/jq -e '.locales // .keyboardLayout // .keyboardOptions // empty' <<< "$OLD_CONFIG_JSON" >/dev/null 2>&1; then
      LOCALES=$(${pkgs.jq}/bin/jq -r '.locales // ["en_US.UTF-8"] | if type == "array" then . | join("\" \"") else . end' <<< "$OLD_CONFIG_JSON" | sed 's/^/"/;s/$/"/')
      KEYBOARD=$(${pkgs.jq}/bin/jq -r '.keyboardLayout // "us"' <<< "$OLD_CONFIG_JSON")
      OPTIONS=$(${pkgs.jq}/bin/jq -r '.keyboardOptions // ""' <<< "$OLD_CONFIG_JSON")
      
      cat > "$CONFIGS_DIR/localization-config.nix" <<LOCEOF
{
  # Localization
  locales = [ $LOCALES ];
  keyboardLayout = "$KEYBOARD";
LOCEOF
      if [ -n "$OPTIONS" ] && [ "$OPTIONS" != "null" ] && [ "$OPTIONS" != "" ]; then
        echo "  keyboardOptions = \"$OPTIONS\";" >> "$CONFIGS_DIR/localization-config.nix"
      fi
      echo "}" >> "$CONFIGS_DIR/localization-config.nix"
      echo "INFO: Created localization-config.nix"
    fi
    
    # Create hardware-config.nix if hardware exists
    if ${pkgs.jq}/bin/jq -e '.hardware // empty | length > 0' <<< "$OLD_CONFIG_JSON" >/dev/null 2>&1; then
      CPU=$(${pkgs.jq}/bin/jq -r '.hardware.cpu // "none"' <<< "$OLD_CONFIG_JSON")
      GPU=$(${pkgs.jq}/bin/jq -r '.hardware.gpu // "none"' <<< "$OLD_CONFIG_JSON")
      MEMORY=$(${pkgs.jq}/bin/jq -r '.hardware.memory.sizeGB // empty' <<< "$OLD_CONFIG_JSON")
      
      cat > "$CONFIGS_DIR/hardware-config.nix" <<HWEOF
{
  hardware = {
    cpu = "$CPU";
    gpu = "$GPU";
HWEOF
      if [ -n "$MEMORY" ] && [ "$MEMORY" != "null" ] && [ "$MEMORY" != "" ]; then
        cat >> "$CONFIGS_DIR/hardware-config.nix" <<HWEOF
    memory = {
      sizeGB = $MEMORY;
    };
HWEOF
      fi
      echo "  };" >> "$CONFIGS_DIR/hardware-config.nix"
      echo "}" >> "$CONFIGS_DIR/hardware-config.nix"
      echo "INFO: Created hardware-config.nix"
    fi
    
    # Create features-config.nix if features exists
    if ${pkgs.jq}/bin/jq -e '.features // empty | length > 0' <<< "$OLD_CONFIG_JSON" >/dev/null 2>&1; then
      SYSTEM_LOGGER=$(${pkgs.jq}/bin/jq -r '.features."system-logger" // false' <<< "$OLD_CONFIG_JSON")
      SYSTEM_CHECKS=$(${pkgs.jq}/bin/jq -r '.features."system-checks" // false' <<< "$OLD_CONFIG_JSON")
      SYSTEM_UPDATER=$(${pkgs.jq}/bin/jq -r '.features."system-updater" // false' <<< "$OLD_CONFIG_JSON")
      SSH_CLIENT=$(${pkgs.jq}/bin/jq -r '.features."ssh-client-manager" // false' <<< "$OLD_CONFIG_JSON")
      SSH_SERVER=$(${pkgs.jq}/bin/jq -r '.features."ssh-server-manager" // false' <<< "$OLD_CONFIG_JSON")
      BOOTENTRY=$(${pkgs.jq}/bin/jq -r '.features."bootentry-manager" // false' <<< "$OLD_CONFIG_JSON")
      HOMELAB=$(${pkgs.jq}/bin/jq -r '.features."homelab-manager" // false' <<< "$OLD_CONFIG_JSON")
      VM=$(${pkgs.jq}/bin/jq -r '.features."vm-manager" // false' <<< "$OLD_CONFIG_JSON")
      AI=$(${pkgs.jq}/bin/jq -r '.features."ai-workspace" // false' <<< "$OLD_CONFIG_JSON")
      
      cat > "$CONFIGS_DIR/features-config.nix" <<FEATURESEOF
{
  features = {
    system-logger = $SYSTEM_LOGGER;
    system-checks = $SYSTEM_CHECKS;
    system-updater = $SYSTEM_UPDATER;
    ssh-client-manager = $SSH_CLIENT;
    ssh-server-manager = $SSH_SERVER;
    bootentry-manager = $BOOTENTRY;
    homelab-manager = $HOMELAB;
    vm-manager = $VM;
    ai-workspace = $AI;
  };
}
FEATURESEOF
      echo "INFO: Created features-config.nix"
    fi
    
    # Create packages-config.nix if packageModules/preset exists
    if ${pkgs.jq}/bin/jq -e '.packageModules // .preset // .additionalPackageModules // empty' <<< "$OLD_CONFIG_JSON" >/dev/null 2>&1; then
      PRESET=$(${pkgs.jq}/bin/jq -r '.preset // "null"' <<< "$OLD_CONFIG_JSON")
      
      cat > "$CONFIGS_DIR/packages-config.nix" <<PKGEOF
{
PKGEOF
      
      if [ "$PRESET" != "null" ] && [ -n "$PRESET" ]; then
        cat >> "$CONFIGS_DIR/packages-config.nix" <<PKGEOF
  # Use preset
  preset = "$PRESET";
PKGEOF
        ADDITIONAL=$(${pkgs.jq}/bin/jq -r '.additionalPackageModules // [] | if type == "array" then . | join(" ") else "[]" end' <<< "$OLD_CONFIG_JSON")
        if [ -n "$ADDITIONAL" ] && [ "$ADDITIONAL" != "[]" ]; then
          ADDITIONAL_LIST=$(echo "$ADDITIONAL" | sed 's/^/    "/;s/ /"\n    "/g;s/$/"/')
          cat >> "$CONFIGS_DIR/packages-config.nix" <<PKGEOF
  additionalPackageModules = [
$ADDITIONAL_LIST
  ];
PKGEOF
        fi
      else
        PACKAGE_MODULES=$(${pkgs.jq}/bin/jq -r '.packageModules // [] | if type == "array" then . | join(" ") else "[]" end' <<< "$OLD_CONFIG_JSON")
        if [ -n "$PACKAGE_MODULES" ] && [ "$PACKAGE_MODULES" != "[]" ]; then
          MODULES_LIST=$(echo "$PACKAGE_MODULES" | sed 's/^/    "/;s/ /"\n    "/g;s/$/"/')
          cat >> "$CONFIGS_DIR/packages-config.nix" <<PKGEOF
  # Package modules directly
  packageModules = [
$MODULES_LIST
  ];
PKGEOF
        else
          cat >> "$CONFIGS_DIR/packages-config.nix" <<PKGEOF
  # Package modules (empty)
  packageModules = [];
PKGEOF
        fi
      fi
      
      echo "}" >> "$CONFIGS_DIR/packages-config.nix"
      echo "INFO: Created packages-config.nix"
    fi
    
    # Create network-config.nix if network settings exist
    if ${pkgs.jq}/bin/jq -e '.enableFirewall // .networking // .networkManager // empty' <<< "$OLD_CONFIG_JSON" >/dev/null 2>&1; then
      FIREWALL=$(${pkgs.jq}/bin/jq -r '.enableFirewall // false' <<< "$OLD_CONFIG_JSON")
      POWERSAVE=$(${pkgs.jq}/bin/jq -r '.enablePowersave // false' <<< "$OLD_CONFIG_JSON")
      DNS=$(${pkgs.jq}/bin/jq -r '.networkManager.dns // "default"' <<< "$OLD_CONFIG_JSON")
      
      cat > "$CONFIGS_DIR/network-config.nix" <<NETEOF
{
  # Firewall
  enableFirewall = $FIREWALL;
  
  # NetworkManager: WiFi Powersave
  enablePowersave = $POWERSAVE;
  
  # NetworkManager: DNS settings
  networkManager = {
    dns = "$DNS";
  };
}
NETEOF
      echo "INFO: Created network-config.nix"
    fi
    
    # Create hosting-config.nix if email/domain exists
    if ${pkgs.jq}/bin/jq -e '.email // .domain // .certEmail // empty' <<< "$OLD_CONFIG_JSON" >/dev/null 2>&1; then
      EMAIL=$(${pkgs.jq}/bin/jq -r '.email // empty' <<< "$OLD_CONFIG_JSON")
      DOMAIN=$(${pkgs.jq}/bin/jq -r '.domain // empty' <<< "$OLD_CONFIG_JSON")
      CERT_EMAIL=$(${pkgs.jq}/bin/jq -r '.certEmail // empty' <<< "$OLD_CONFIG_JSON")
      
      cat > "$CONFIGS_DIR/hosting-config.nix" <<HOSTEOF
{
HOSTEOF
      if [ -n "$EMAIL" ] && [ "$EMAIL" != "null" ] && [ "$EMAIL" != "" ]; then
        echo "  email = \"$EMAIL\";" >> "$CONFIGS_DIR/hosting-config.nix"
      fi
      if [ -n "$DOMAIN" ] && [ "$DOMAIN" != "null" ] && [ "$DOMAIN" != "" ]; then
        echo "  domain = \"$DOMAIN\";" >> "$CONFIGS_DIR/hosting-config.nix"
      fi
      if [ -n "$CERT_EMAIL" ] && [ "$CERT_EMAIL" != "null" ] && [ "$CERT_EMAIL" != "" ]; then
        echo "  certEmail = \"$CERT_EMAIL\";" >> "$CONFIGS_DIR/hosting-config.nix"
      fi
      echo "}" >> "$CONFIGS_DIR/hosting-config.nix"
      echo "INFO: Created hosting-config.nix"
    fi
    
    # Create overrides-config.nix if overrides exists
    if ${pkgs.jq}/bin/jq -e '.overrides // empty | length > 0' <<< "$OLD_CONFIG_JSON" >/dev/null 2>&1; then
      SSH_OVERRIDE=$(${pkgs.jq}/bin/jq -r '.overrides.enableSSH // "null"' <<< "$OLD_CONFIG_JSON")
      STEAM_OVERRIDE=$(${pkgs.jq}/bin/jq -r '.overrides.enableSteam // false' <<< "$OLD_CONFIG_JSON")
      
      cat > "$CONFIGS_DIR/overrides-config.nix" <<OVERRIDEEOF
{
  overrides = {
OVERRIDEEOF
      if [ "$SSH_OVERRIDE" != "null" ] && [ -n "$SSH_OVERRIDE" ]; then
        echo "    enableSSH = $SSH_OVERRIDE;" >> "$CONFIGS_DIR/overrides-config.nix"
      else
        echo "    enableSSH = null;" >> "$CONFIGS_DIR/overrides-config.nix"
      fi
      echo "    enableSteam = $STEAM_OVERRIDE;" >> "$CONFIGS_DIR/overrides-config.nix"
      echo "  };" >> "$CONFIGS_DIR/overrides-config.nix"
      echo "}" >> "$CONFIGS_DIR/overrides-config.nix"
      echo "INFO: Created overrides-config.nix"
    fi
    
    # Create logging-config.nix if buildLogLevel exists
    if ${pkgs.jq}/bin/jq -e '.buildLogLevel // empty' <<< "$OLD_CONFIG_JSON" >/dev/null 2>&1; then
      LOG_LEVEL=$(${pkgs.jq}/bin/jq -r '.buildLogLevel // "minimal"' <<< "$OLD_CONFIG_JSON")
      
      cat > "$CONFIGS_DIR/logging-config.nix" <<LOGEOF
{
  # Build Logging
  buildLogLevel = "$LOG_LEVEL";
}
LOGEOF
      echo "INFO: Created logging-config.nix"
    fi
    
    echo "SUCCESS: Migration completed successfully!"
    echo "INFO: Backup saved at: $BACKUP_FILE"
  '';

in {
  inherit migrateSystemConfig;
}

