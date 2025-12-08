#!/usr/bin/env bash

# Automatic migration from old system-config.nix to new modular structure
# Checks if old structure exists and migrates automatically

migrate_system_config() {
    log_section "System-Config Migration"
    
    local config_file="${SYSTEM_CONFIG_FILE:-/etc/nixos/system-config.nix}"
    local configs_dir="$(dirname "$config_file")/configs"
    
    # Check if system-config.nix exists
    if [[ ! -f "$config_file" ]]; then
        log_info "system-config.nix not found, no migration needed"
        return 0
    fi
    
    # 1. VALIDIERUNG ZUERST: Prüfe ob system-config.nix der Spezifikation entspricht
    if validate_system_config "$config_file"; then
        log_info "system-config.nix is valid, no migration needed"
        return 0
    fi
    
    # 2. Wenn Validierung FAILED → Diagnose: Warum? (alte Struktur?)
    if ! is_old_structure "$config_file"; then
        log_warn "system-config.nix validation failed, but structure unknown"
        log_info "Skipping migration, manual intervention may be required"
        return 0
    fi
    
    log_info "Old structure detected, starting migration..."
    
    # Create backup
    backup_file "$config_file" || {
        log_error "Backup failed"
        return 1
    }
    
    # Create configs directory
    ensure_dir "$configs_dir" || {
        log_error "Could not create configs directory"
        return 1
    }
    
    # Load old config with nix-instantiate
    local old_config
    if ! old_config=$(nix-instantiate --eval --strict --json -E "import $config_file" 2>/dev/null); then
        # Fallback: Try with nix eval
        if ! old_config=$(nix eval --json --file "$config_file" 2>/dev/null); then
            log_error "Could not load old system-config.nix (requires nix-instantiate or nix)"
            log_info "Migration will be skipped, manual migration required"
            return 0  # Not critical, setup can continue
        fi
    fi
    
    # Extract values and create new config files
    migrate_to_new_structure "$config_file" "$old_config" || {
        log_error "Migration failed"
        return 1
    }
    
    log_success "Migration completed successfully!"
    return 0
}

# Validate system-config.nix against specification
validate_system_config() {
    local config_file="$1"
    local errors=0
    
    # Check for required critical values (from config-validator.nix)
    local critical_values=("systemType" "hostName" "system.channel" "system.bootloader" "allowUnfree" "users" "timeZone")
    for value in "${critical_values[@]}"; do
        if ! nix-instantiate --eval --strict -E "(import $config_file).$value or null" >/dev/null 2>&1; then
            log_debug "Missing required value: $value"
            errors=$((errors + 1))
        fi
    done
    
    # Check for non-critical values (should NOT be in system-config.nix)
    if grep -q "packageModules = " "$config_file" 2>/dev/null || \
       grep -q "desktop = {" "$config_file" 2>/dev/null || \
       grep -q "hardware = {" "$config_file" 2>/dev/null || \
       grep -q "features = {" "$config_file" 2>/dev/null; then
        log_debug "Non-critical values found in system-config.nix (should be in configs/)"
        errors=$((errors + 1))
    fi
    
    # Check if minimal (< 30 lines)
    local line_count=$(wc -l < "$config_file" 2>/dev/null || echo "0")
    if [[ "$line_count" -gt 30 ]]; then
        log_debug "system-config.nix has more than 30 lines (should be minimal)"
        errors=$((errors + 1))
    fi
    
    # Return 0 if valid, 1 if invalid
    return $errors
}

# Check if old structure exists
is_old_structure() {
    local config_file="$1"
    
    # Count lines in system-config.nix
    local line_count=$(wc -l < "$config_file" 2>/dev/null || echo "0")
    
    # If more than 20 lines, it's probably old structure
    if [[ "$line_count" -gt 20 ]]; then
        return 0  # Old structure
    fi
    
    # Check if non-critical values are present
    if grep -q "desktop = {" "$config_file" 2>/dev/null || \
       grep -q "hardware = {" "$config_file" 2>/dev/null || \
       grep -q "features = {" "$config_file" 2>/dev/null || \
       grep -q "packageModules = " "$config_file" 2>/dev/null; then
        return 0  # Old structure
    fi
    
    return 1  # New structure
}

# Migrate to new structure
migrate_to_new_structure() {
    local config_file="$1"
    local old_config_json="$2"
    
    log_info "Extracting values from old config..."
    
    # Extract critical values for system-config.nix
    local system_type=$(extract_value "$old_config_json" "systemType" || echo "desktop")
    local hostname=$(extract_value "$old_config_json" "hostName" || echo "$(hostname)")
    local channel=$(extract_value "$old_config_json" "system.channel" || echo "stable")
    local bootloader=$(extract_value "$old_config_json" "system.bootloader" || echo "systemd-boot")
    local allow_unfree=$(extract_value "$old_config_json" "allowUnfree" || echo "true")
    local timezone=$(extract_value "$old_config_json" "timeZone" || echo "Europe/Berlin")
    
    # Extract users (complex, as it's a Nix set)
    local users_block=$(extract_users_block "$config_file")
    
    # Create minimal system-config.nix
    create_minimal_system_config "$config_file" "$system_type" "$hostname" "$channel" "$bootloader" "$allow_unfree" "$timezone" "$users_block" || return 1
    
    # Create desktop-config.nix
    if has_desktop_config "$old_config_json"; then
        create_desktop_config "$configs_dir" "$old_config_json" || return 1
    fi
    
    # Create localization-config.nix
    if has_localization_config "$old_config_json"; then
        create_localization_config "$configs_dir" "$old_config_json" || return 1
    fi
    
    # Create hardware-config.nix
    if has_hardware_config "$old_config_json"; then
        create_hardware_config "$configs_dir" "$old_config_json" || return 1
    fi
    
    # Create features-config.nix
    if has_features_config "$old_config_json"; then
        create_features_config "$configs_dir" "$old_config_json" || return 1
    fi
    
    # Create packages-config.nix
    if has_packages_config "$old_config_json"; then
        create_packages_config "$configs_dir" "$old_config_json" || return 1
    fi
    
    # Create network-config.nix
    if has_network_config "$old_config_json"; then
        create_network_config "$configs_dir" "$old_config_json" || return 1
    fi
    
    # Create hosting-config.nix
    if has_hosting_config "$old_config_json"; then
        create_hosting_config "$configs_dir" "$old_config_json" || return 1
    fi
    
    # Create overrides-config.nix
    if has_overrides_config "$old_config_json"; then
        create_overrides_config "$configs_dir" "$old_config_json" || return 1
    fi
    
    # Create logging-config.nix
    if has_logging_config "$old_config_json"; then
        create_logging_config "$configs_dir" "$old_config_json" || return 1
    fi
    
    log_success "All config files created"
    return 0
}

# Helper: Extract value from JSON
extract_value() {
    local json="$1"
    local key="$2"
    
    # Check if jq is available
    if ! command -v jq >/dev/null 2>&1; then
        log_warn "jq not available, using simple extraction"
        # Simple extraction without jq (not ideal, but works for simple values)
        echo "$json" | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" | cut -d'"' -f4 || echo ""
        return 0
    fi
    
    echo "$json" | jq -r ".$key // empty" 2>/dev/null || echo ""
}

# Helper: Extract users block from Nix file (since JSON is too complex)
extract_users_block() {
    local config_file="$1"
    
    # Try to extract users block
    if grep -q "users = {" "$config_file" 2>/dev/null; then
        # Extract users block between { and };
        awk '/users = {/,/^  };/' "$config_file" | sed '1d;$d' | sed 's/^/    /'
    else
        echo ""
    fi
}

# Helper: Check if config exists (with fallback if jq is missing)
has_desktop_config() {
    local json="$1"
    if command -v jq >/dev/null 2>&1; then
        echo "$json" | jq -e '.desktop // empty | length > 0' >/dev/null 2>&1
    else
        # Fallback: Check with grep
        echo "$json" | grep -q '"desktop"' 2>/dev/null
    fi
}

has_localization_config() {
    local json="$1"
    if command -v jq >/dev/null 2>&1; then
        echo "$json" | jq -e '.locales // .keyboardLayout // .keyboardOptions // empty' >/dev/null 2>&1
    else
        echo "$json" | grep -qE '"locales"|"keyboardLayout"|"keyboardOptions"' 2>/dev/null
    fi
}

has_hardware_config() {
    local json="$1"
    if command -v jq >/dev/null 2>&1; then
        echo "$json" | jq -e '.hardware // empty | length > 0' >/dev/null 2>&1
    else
        echo "$json" | grep -q '"hardware"' 2>/dev/null
    fi
}

has_features_config() {
    local json="$1"
    if command -v jq >/dev/null 2>&1; then
        echo "$json" | jq -e '.features // empty | length > 0' >/dev/null 2>&1
    else
        echo "$json" | grep -q '"features"' 2>/dev/null
    fi
}

has_packages_config() {
    local json="$1"
    if command -v jq >/dev/null 2>&1; then
        echo "$json" | jq -e '.packageModules // .preset // .additionalPackageModules // empty' >/dev/null 2>&1
    else
        echo "$json" | grep -qE '"packageModules"|"preset"|"additionalPackageModules"' 2>/dev/null
    fi
}

has_network_config() {
    local json="$1"
    if command -v jq >/dev/null 2>&1; then
        echo "$json" | jq -e '.enableFirewall // .networking // .networkManager // empty' >/dev/null 2>&1
    else
        echo "$json" | grep -qE '"enableFirewall"|"networking"|"networkManager"' 2>/dev/null
    fi
}

has_hosting_config() {
    local json="$1"
    if command -v jq >/dev/null 2>&1; then
        echo "$json" | jq -e '.email // .domain // .certEmail // empty' >/dev/null 2>&1
    else
        echo "$json" | grep -qE '"email"|"domain"|"certEmail"' 2>/dev/null
    fi
}

has_overrides_config() {
    local json="$1"
    if command -v jq >/dev/null 2>&1; then
        echo "$json" | jq -e '.overrides // empty | length > 0' >/dev/null 2>&1
    else
        echo "$json" | grep -q '"overrides"' 2>/dev/null
    fi
}

has_logging_config() {
    local json="$1"
    if command -v jq >/dev/null 2>&1; then
        echo "$json" | jq -e '.buildLogLevel // empty' >/dev/null 2>&1
    else
        echo "$json" | grep -q '"buildLogLevel"' 2>/dev/null
    fi
}

# Create minimal system-config.nix
create_minimal_system_config() {
    local config_file="$1"
    local system_type="$2"
    local hostname="$3"
    local channel="$4"
    local bootloader="$5"
    local allow_unfree="$6"
    local timezone="$7"
    local users_block="$8"
    
    local users_content=""
    if [[ -n "$users_block" ]]; then
        users_content="$users_block"
    else
        users_content="    # Users will be added later"
    fi
    
    cat > "$config_file" <<EOF
{
  # Configuration Schema Version
  configVersion = "1.0";
  
  # System Identity
  systemType = "$system_type";
  hostName = "$hostname";
  
  # System Version
  system = {
    channel = "$channel";
    bootloader = "$bootloader";
  };
  
  # Nix Config
  allowUnfree = $allow_unfree;
  
  # User Management
  users = {
$users_content
  };
  
  # TimeZone
  timeZone = "$timezone";
}
EOF
    
    log_success "Minimal system-config.nix created"
}

# Create desktop-config.nix
create_desktop_config() {
    local configs_dir="$1"
    local json="$2"
    
    local enable="false"
    local env="plasma"
    local manager="sddm"
    local server="wayland"
    local session="plasma"
    local dark="true"
    local audio="pipewire"
    
    if command -v jq >/dev/null 2>&1; then
        enable=$(echo "$json" | jq -r '.desktop.enable // false')
        env=$(echo "$json" | jq -r '.desktop.environment // "plasma"')
        manager=$(echo "$json" | jq -r '.desktop.display.manager // "sddm"')
        server=$(echo "$json" | jq -r '.desktop.display.server // "wayland"')
        session=$(echo "$json" | jq -r '.desktop.display.session // "plasma"')
        dark=$(echo "$json" | jq -r '.desktop.theme.dark // true')
        audio=$(echo "$json" | jq -r '.desktop.audio // "pipewire"')
    else
        # Fallback: Extract from Nix file directly
        local config_file="${SYSTEM_CONFIG_FILE:-/etc/nixos/system-config.nix}"
        enable=$(grep -o 'desktop.*enable.*=.*[^;]*' "$config_file" 2>/dev/null | grep -oE '(true|false)' | head -1 || echo "false")
        env=$(grep -o 'environment.*=.*"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "plasma")
        manager=$(grep -o 'manager.*=.*"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "sddm")
        server=$(grep -o 'server.*=.*"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "wayland")
        session=$(grep -o 'session.*=.*"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "plasma")
        dark=$(grep -o 'dark.*=.*[^;]*' "$config_file" 2>/dev/null | grep -oE '(true|false)' | head -1 || echo "true")
        audio=$(grep -o 'audio.*=.*"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "pipewire")
    fi
    
    cat > "$configs_dir/desktop-config.nix" <<EOF
{
  # Desktop Environment
  desktop = {
    enable = $enable;
    environment = "$env";
    display = {
      manager = "$manager";
      server = "$server";
      session = "$session";
    };
    theme = {
      dark = $dark;
    };
    audio = "$audio";
  };
}
EOF
    
    log_success "desktop-config.nix created"
}

# Create localization-config.nix
create_localization_config() {
    local configs_dir="$1"
    local json="$2"
    
    local locales='"en_US.UTF-8"'
    local keyboard="us"
    local options=""
    
    if command -v jq >/dev/null 2>&1; then
        locales=$(echo "$json" | jq -r '.locales // ["en_US.UTF-8"] | if type == "array" then . | join("\" \"") else . end' | sed 's/^/"/;s/$/"/')
        keyboard=$(echo "$json" | jq -r '.keyboardLayout // "us"')
        options=$(echo "$json" | jq -r '.keyboardOptions // ""')
    else
        # Fallback: Extract from Nix file directly
        local config_file="${SYSTEM_CONFIG_FILE:-/etc/nixos/system-config.nix}"
        locales=$(grep -o 'locales.*=.*\[[^]]*\]' "$config_file" 2>/dev/null | grep -o '"[^"]*"' | head -1 || echo '"en_US.UTF-8"')
        keyboard=$(grep -o 'keyboardLayout.*=.*"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "us")
        options=$(grep -o 'keyboardOptions.*=.*"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "")
    fi
    
    cat > "$configs_dir/localization-config.nix" <<EOF
{
  # Localization
  locales = [ $locales ];
  keyboardLayout = "$keyboard";
EOF
    
    if [[ -n "$options" && "$options" != "null" && "$options" != "" ]]; then
        echo "  keyboardOptions = \"$options\";" >> "$configs_dir/localization-config.nix"
    fi
    
    echo "}" >> "$configs_dir/localization-config.nix"
    
    log_success "localization-config.nix created"
}

# Create hardware-config.nix
create_hardware_config() {
    local configs_dir="$1"
    local json="$2"
    
    local cpu="none"
    local gpu="none"
    local memory=""
    
    if command -v jq >/dev/null 2>&1; then
        cpu=$(echo "$json" | jq -r '.hardware.cpu // "none"')
        gpu=$(echo "$json" | jq -r '.hardware.gpu // "none"')
        # Support both v1.0 (hardware.memory.sizeGB) and v2.0 (hardware.ram.sizeGB)
        memory=$(echo "$json" | jq -r '.hardware.ram.sizeGB // .hardware.memory.sizeGB // empty')
    else
        # Fallback: Extract from Nix file directly
        local config_file="${SYSTEM_CONFIG_FILE:-/etc/nixos/system-config.nix}"
        cpu=$(grep -o 'cpu.*=.*"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "none")
        gpu=$(grep -o 'gpu.*=.*"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "none")
        # Support both v1.0 (memory) and v2.0 (ram)
        memory=$(grep -A2 'ram = {' "$config_file" 2>/dev/null | grep 'sizeGB' | grep -o '[0-9]\+' || \
                 grep -A2 'memory = {' "$config_file" 2>/dev/null | grep 'sizeGB' | grep -o '[0-9]\+' || echo "")
    fi
    
    cat > "$configs_dir/hardware-config.nix" <<EOF
{
  hardware = {
    cpu = "$cpu";
    gpu = "$gpu";
EOF
    
    if [[ -n "$memory" && "$memory" != "null" && "$memory" != "" ]]; then
        cat >> "$configs_dir/hardware-config.nix" <<EOF
    ram = {
      sizeGB = $memory;
    };
EOF
    fi
    
    echo "  };" >> "$configs_dir/hardware-config.nix"
    echo "}" >> "$configs_dir/hardware-config.nix"
    
    log_success "hardware-config.nix created"
}

# Create features-config.nix
create_features_config() {
    local configs_dir="$1"
    local json="$2"
    
    local system_logger="false"
    local system_checks="false"
    local system_updater="false"
    local ssh_client="false"
    local ssh_server="false"
    local bootentry="false"
    local homelab="false"
    local vm="false"
    local ai="false"
    
    if command -v jq >/dev/null 2>&1; then
        system_logger=$(echo "$json" | jq -r '.features."system-logger" // false')
        system_checks=$(echo "$json" | jq -r '.features."system-checks" // false')
        system_updater=$(echo "$json" | jq -r '.features."system-updater" // false')
        ssh_client=$(echo "$json" | jq -r '.features."ssh-client-manager" // false')
        ssh_server=$(echo "$json" | jq -r '.features."ssh-server-manager" // false')
        bootentry=$(echo "$json" | jq -r '.features."bootentry-manager" // false')
        homelab=$(echo "$json" | jq -r '.features."homelab-manager" // false')
        vm=$(echo "$json" | jq -r '.features."vm-manager" // false')
        ai=$(echo "$json" | jq -r '.features."ai-workspace" // false')
    else
        # Fallback: Extract from Nix file directly
        local config_file="${SYSTEM_CONFIG_FILE:-/etc/nixos/system-config.nix}"
        system_logger=$(grep -o 'system-logger.*=.*[^;]*' "$config_file" 2>/dev/null | grep -oE '(true|false)' | head -1 || echo "false")
        system_checks=$(grep -o 'system-checks.*=.*[^;]*' "$config_file" 2>/dev/null | grep -oE '(true|false)' | head -1 || echo "false")
        system_updater=$(grep -o 'system-updater.*=.*[^;]*' "$config_file" 2>/dev/null | grep -oE '(true|false)' | head -1 || echo "false")
        ssh_client=$(grep -o 'ssh-client-manager.*=.*[^;]*' "$config_file" 2>/dev/null | grep -oE '(true|false)' | head -1 || echo "false")
        ssh_server=$(grep -o 'ssh-server-manager.*=.*[^;]*' "$config_file" 2>/dev/null | grep -oE '(true|false)' | head -1 || echo "false")
        bootentry=$(grep -o 'bootentry-manager.*=.*[^;]*' "$config_file" 2>/dev/null | grep -oE '(true|false)' | head -1 || echo "false")
        homelab=$(grep -o 'homelab-manager.*=.*[^;]*' "$config_file" 2>/dev/null | grep -oE '(true|false)' | head -1 || echo "false")
        vm=$(grep -o 'vm-manager.*=.*[^;]*' "$config_file" 2>/dev/null | grep -oE '(true|false)' | head -1 || echo "false")
        ai=$(grep -o 'ai-workspace.*=.*[^;]*' "$config_file" 2>/dev/null | grep -oE '(true|false)' | head -1 || echo "false")
    fi
    
    cat > "$configs_dir/features-config.nix" <<EOF
{
  features = {
    system-logger = $system_logger;
    system-checks = $system_checks;
    system-updater = $system_updater;
    ssh-client-manager = $ssh_client;
    ssh-server-manager = $ssh_server;
    bootentry-manager = $bootentry;
    homelab-manager = $homelab;
    vm-manager = $vm;
    ai-workspace = $ai;
  };
}
EOF
    
    log_success "features-config.nix created"
}

# Create packages-config.nix
create_packages_config() {
    local configs_dir="$1"
    local json="$2"
    
    local preset="null"
    local package_modules=""
    local additional=""
    
    if command -v jq >/dev/null 2>&1; then
        preset=$(echo "$json" | jq -r '.preset // "null"')
        package_modules=$(echo "$json" | jq -r '.packageModules // [] | if type == "array" then . | join(" ") else "[]" end')
        additional=$(echo "$json" | jq -r '.additionalPackageModules // [] | if type == "array" then . | join(" ") else "[]" end')
    else
        # Fallback: Extract from Nix file directly
        local config_file="${SYSTEM_CONFIG_FILE:-/etc/nixos/system-config.nix}"
        preset=$(grep -o 'preset.*=.*[^;]*' "$config_file" 2>/dev/null | grep -oE '"[^"]*"|null' | head -1 | tr -d '"' || echo "null")
        # Extract packageModules array
        if grep -q 'packageModules = \[' "$config_file" 2>/dev/null; then
            package_modules=$(awk '/packageModules = \[/,/\];/' "$config_file" | grep -o '"[^"]*"' | tr -d '"' | tr '\n' ' ' | sed 's/ $//')
        fi
        # Extract additionalPackageModules array
        if grep -q 'additionalPackageModules = \[' "$config_file" 2>/dev/null; then
            additional=$(awk '/additionalPackageModules = \[/,/\];/' "$config_file" | grep -o '"[^"]*"' | tr -d '"' | tr '\n' ' ' | sed 's/ $//')
        fi
    fi
    
    cat > "$configs_dir/packages-config.nix" <<EOF
{
EOF
    
    if [[ "$preset" != "null" && -n "$preset" ]]; then
        cat >> "$configs_dir/packages-config.nix" <<EOF
  # Use preset
  preset = "$preset";
EOF
        if [[ -n "$additional" && "$additional" != "[]" ]]; then
            # Filter out empty strings and format properly
            cat >> "$configs_dir/packages-config.nix" <<EOF
  additionalPackageModules = [
EOF
            local first=true
            for module in $additional; do
                # Skip empty strings
                [[ -z "$module" ]] && continue
                echo "    \"$module\"" >> "$configs_dir/packages-config.nix"
            done
            cat >> "$configs_dir/packages-config.nix" <<EOF
  ];
EOF
        fi
    else
        if [[ -n "$package_modules" && "$package_modules" != "[]" ]]; then
            # Filter out empty strings and format properly
            cat >> "$configs_dir/packages-config.nix" <<EOF
  # Package modules directly
  packageModules = [
EOF
            local first=true
            for module in $package_modules; do
                # Skip empty strings
                [[ -z "$module" ]] && continue
                if [[ "$first" == "true" ]]; then
                    echo "    \"$module\"" >> "$configs_dir/packages-config.nix"
                    first=false
                else
                    echo "    \"$module\"" >> "$configs_dir/packages-config.nix"
                fi
            done
            cat >> "$configs_dir/packages-config.nix" <<EOF
  ];
EOF
        else
            cat >> "$configs_dir/packages-config.nix" <<EOF
  # Package modules (empty)
  packageModules = [];
EOF
        fi
    fi
    
    echo "}" >> "$configs_dir/packages-config.nix"
    
    log_success "packages-config.nix created"
}

# Create network-config.nix
create_network_config() {
    local configs_dir="$1"
    local json="$2"
    
    local firewall="false"
    local powersave="false"
    local dns="default"
    
    if command -v jq >/dev/null 2>&1; then
        firewall=$(echo "$json" | jq -r '.enableFirewall // false')
        powersave=$(echo "$json" | jq -r '.enablePowersave // false')
        dns=$(echo "$json" | jq -r '.networkManager.dns // "default"')
    else
        # Fallback: Extract from Nix file directly
        local config_file="${SYSTEM_CONFIG_FILE:-/etc/nixos/system-config.nix}"
        firewall=$(grep -o 'enableFirewall.*=.*[^;]*' "$config_file" 2>/dev/null | grep -oE '(true|false)' | head -1 || echo "false")
        powersave=$(grep -o 'enablePowersave.*=.*[^;]*' "$config_file" 2>/dev/null | grep -oE '(true|false)' | head -1 || echo "false")
        dns=$(grep -o 'dns.*=.*"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "default")
    fi
    
    cat > "$configs_dir/network-config.nix" <<EOF
{
  # Firewall
  enableFirewall = $firewall;
  
  # NetworkManager: WiFi Powersave
  enablePowersave = $powersave;
  
  # NetworkManager: DNS settings
  networkManager = {
    dns = "$dns";
  };
}
EOF
    
    log_success "network-config.nix created"
}

# Create hosting-config.nix
create_hosting_config() {
    local configs_dir="$1"
    local json="$2"
    
    local email=""
    local domain=""
    local cert_email=""
    
    if command -v jq >/dev/null 2>&1; then
        email=$(echo "$json" | jq -r '.email // empty')
        domain=$(echo "$json" | jq -r '.domain // empty')
        cert_email=$(echo "$json" | jq -r '.certEmail // empty')
    else
        # Fallback: Extract from Nix file directly
        local config_file="${SYSTEM_CONFIG_FILE:-/etc/nixos/system-config.nix}"
        email=$(grep -o 'email.*=.*"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "")
        domain=$(grep -o 'domain.*=.*"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "")
        cert_email=$(grep -o 'certEmail.*=.*"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "")
    fi
    
    cat > "$configs_dir/hosting-config.nix" <<EOF
{
EOF
    
    if [[ -n "$email" && "$email" != "null" && "$email" != "" ]]; then
        echo "  email = \"$email\";" >> "$configs_dir/hosting-config.nix"
    fi
    if [[ -n "$domain" && "$domain" != "null" && "$domain" != "" ]]; then
        echo "  domain = \"$domain\";" >> "$configs_dir/hosting-config.nix"
    fi
    if [[ -n "$cert_email" && "$cert_email" != "null" && "$cert_email" != "" ]]; then
        echo "  certEmail = \"$cert_email\";" >> "$configs_dir/hosting-config.nix"
    fi
    
    echo "}" >> "$configs_dir/hosting-config.nix"
    
    log_success "hosting-config.nix created"
}

# Create overrides-config.nix
create_overrides_config() {
    local configs_dir="$1"
    local json="$2"
    
    local ssh_override="null"
    
    if command -v jq >/dev/null 2>&1; then
        ssh_override=$(echo "$json" | jq -r '.overrides.enableSSH // "null"')
    else
        # Fallback: Extract from Nix file directly
        local config_file="${SYSTEM_CONFIG_FILE:-/etc/nixos/system-config.nix}"
        ssh_override=$(grep -o 'enableSSH.*=.*[^;]*' "$config_file" 2>/dev/null | grep -oE '(true|false|null)' | head -1 || echo "null")
    fi
    
    cat > "$configs_dir/overrides-config.nix" <<EOF
{
  overrides = {
EOF
    
    if [[ "$ssh_override" != "null" && -n "$ssh_override" ]]; then
        echo "    enableSSH = $ssh_override;" >> "$configs_dir/overrides-config.nix"
    else
        echo "    enableSSH = null;" >> "$configs_dir/overrides-config.nix"
    fi
    
    echo "  };" >> "$configs_dir/overrides-config.nix"
    echo "}" >> "$configs_dir/overrides-config.nix"
    
    log_success "overrides-config.nix created"
}

# Create logging-config.nix
create_logging_config() {
    local configs_dir="$1"
    local json="$2"
    
    local log_level="minimal"
    
    if command -v jq >/dev/null 2>&1; then
        log_level=$(echo "$json" | jq -r '.buildLogLevel // "minimal"')
    else
        # Fallback: Extract from Nix file directly
        local config_file="${SYSTEM_CONFIG_FILE:-/etc/nixos/system-config.nix}"
        log_level=$(grep -o 'buildLogLevel.*=.*"[^"]*"' "$config_file" 2>/dev/null | cut -d'"' -f2 || echo "minimal")
    fi
    
    cat > "$configs_dir/logging-config.nix" <<EOF
{
  # Build Logging
  buildLogLevel = "$log_level";
}
EOF
    
    log_success "logging-config.nix created"
}

# Export functions
export -f migrate_system_config
export -f validate_system_config
export -f is_old_structure
export -f migrate_to_new_structure

# Check script execution
check_script_execution "SYSTEM_CONFIG_FILE" "migrate_system_config"

