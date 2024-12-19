#!/usr/bin/env bash


log_section "Checking User Configuration"

# Funktion zum Prüfen von Pfaden
check_path() {
    local path="$1"
    local desc="$2"
    if [ -e "$path" ]; then
        echo -e "  ${desc}: ${GREEN}Found${NC} (${GRAY}${path}${NC})"
        return 0
    else
        echo -e "  ${desc}: ${YELLOW}Not found${NC} (${GRAY}${path}${NC})"
        return 1
    fi
}

# Aktuelle User-Informationen
log_info "Current User Details:"
current_user=$(whoami)
current_home=$(eval echo ~$current_user)
echo -e "  User     : ${CYAN}${current_user}${NC}"
echo -e "  Home     : ${CYAN}${current_home}${NC}"

# Prüfe User-Gruppen
log_info "Group Memberships:"
groups=$(groups "$current_user")
groups=${groups#*: }
echo -e "  Groups   : ${GRAY}${groups}${NC}"

# Wichtige Gruppen prüfen
important_groups=("wheel" "audio" "video" "input" "networkmanager")
missing_groups=()
for group in "${important_groups[@]}"; do
    if ! echo "$groups" | tr ' ' '\n' | grep -q "^${group}$"; then
        missing_groups+=("$group")
    fi
done

if [ ${#missing_groups[@]} -gt 0 ]; then
    echo -e "  ${YELLOW}Missing recommended groups: ${missing_groups[*]}${NC}"
    echo -e "  ${GRAY}Tip: Use 'sudo usermod -aG group_name $current_user' to add groups${NC}"
fi

# Konfigurationspfade prüfen
log_info "Configuration Paths:"

# NixOS Konfigurationen suchen
log_info "NixOS Configuration:"
if [ -r "/etc/nixos" ]; then
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            if [[ "$file" == *"flake.nix" ]]; then
                flake_found=true
                found_flakes+=("$file")
                echo -e "  Flake Config: ${GREEN}Found${NC} (${GRAY}${file}${NC})"
            elif [[ "$file" == *"home.nix" ]]; then
                hm_found=true
                found_hm_configs+=("$file")
                echo -e "  Home Manager: ${GREEN}Found${NC} (${GRAY}${file}${NC})"
            elif [[ "$file" == *"configuration.nix" ]]; then
                echo -e "  NixOS Config: ${GREEN}Found${NC} (${GRAY}${file}${NC})"
            fi
        fi
    done < <(find /etc/nixos -name "*.nix" 2>/dev/null)
else
    # Wenn keine Leserechte, versuche es mit sudo
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            if [[ "$file" == *"flake.nix" ]]; then
                flake_found=true
                found_flakes+=("$file")
                echo -e "  Flake Config: ${GREEN}Found${NC} (${GRAY}${file}${NC})"
            elif [[ "$file" == *"home.nix" ]]; then
                hm_found=true
                found_hm_configs+=("$file")
                echo -e "  Home Manager: ${GREEN}Found${NC} (${GRAY}${file}${NC})"
            elif [[ "$file" == *"configuration.nix" ]]; then
                echo -e "  NixOS Config: ${GREEN}Found${NC} (${GRAY}${file}${NC})"
            fi
        fi
    done < <(sudo find /etc/nixos -name "*.nix" 2>/dev/null)
fi

if ! $flake_found && ! $hm_found; then
    echo -e "  ${YELLOW}No configuration files found in /etc/nixos${NC}"
fi

# Shell-Konfiguration
log_info "Shell Configuration:"
current_shell=$(getent passwd $current_user | cut -d: -f7)
echo -e "  Shell    : ${CYAN}${current_shell}${NC}"

# Prüfe Shell-Berechtigungen
if [[ -x "$current_shell" ]]; then
    echo -e "  Access   : ${GREEN}Executable${NC}"
else
    echo -e "  Access   : ${YELLOW}Not executable${NC}"
fi

# Prüfe Shell in /etc/shells
if grep -q "^${current_shell}$" /etc/shells 2>/dev/null; then
    echo -e "  Valid    : ${GREEN}Listed in /etc/shells${NC}"
else
    echo -e "  Valid    : ${YELLOW}Not listed in /etc/shells${NC}"
fi

# Prüfe ob es die Standard-Shell ist
if [[ "$SHELL" == "$current_shell" ]]; then
    echo -e "  Default  : ${GREEN}Yes${NC}"
else
    echo -e "  Default  : ${YELLOW}No (SHELL=$SHELL)${NC}"
fi

# Prüfe wichtige Dotfiles
log_info "Important Dotfiles:"
dotfiles=(".profile" ".bashrc" ".zshrc" ".config/fish/config.fish")
for file in "${dotfiles[@]}"; do
    check_path "$current_home/$file" "${file}"
done

# Prüfe wichtige Home-Verzeichnisse
log_info "Home Directory Structure:"
important_dirs=(
    "Documents"
    "Downloads"
    "Pictures"
    "Videos"
    "Music"
    ".ssh"
    ".local/share"
    ".config"
)

for dir in "${important_dirs[@]}"; do
    if [ -d "$current_home/$dir" ]; then
        echo -e "  ${dir}: ${GREEN}Exists${NC}"
    else
        echo -e "  ${dir}: ${YELLOW}Missing${NC}"
    fi
done

# Prüfe Backup-Konfiguration
log_info "Backup Status:"
if [ -d "$current_home/.backup" ] || [ -f "$current_home/.config/backup.conf" ]; then
    echo -e "  ${GREEN}✓${NC} Backup configuration found"
else
    echo -e "  ${YELLOW}!${NC} No backup configuration found"
    echo -e "    ${GRAY}Tip: Consider setting up backups before system changes${NC}"
fi

# Zusammenfassung am Ende
log_info "Summary:"
if $hm_found; then
    echo -e "  ${GREEN}✓${NC} Home Manager configuration(s) found:"
    for config in "${found_hm_configs[@]}"; do
        echo -e "    ${GRAY}- ${config}${NC}"
    done
else
    echo -e "  ${YELLOW}!${NC} No Home Manager configuration found"
    echo -e "    ${GRAY}Tip: Run 'nix-shell -p home-manager' and then 'home-manager init' to get started${NC}"
fi

if $flake_found; then
    echo -e "  ${GREEN}✓${NC} Flake configuration found"
    for flake in "${found_flakes[@]}"; do
        echo -e "    ${GRAY}- ${flake}${NC}"
    done
else
    echo -e "  ${YELLOW}!${NC} No Flake configuration found"
    echo -e "    ${GRAY}Tip: Create a flake.nix file in /etc/nixos/ or ~/.config/nixos/${NC}"
fi

if [ ${#missing_groups[@]} -gt 0 ]; then
    echo -e "  ${YELLOW}!${NC} Some recommended groups missing"
    if [[ " ${missing_groups[*]} " =~ " wheel " ]]; then
        echo -e "    ${GRAY}Note: 'wheel' group is needed for sudo access${NC}"
    fi
fi

# Füge Backup-Warnung hinzu wenn nötig
if [ ! -d "$current_home/.backup" ] && [ ! -f "$current_home/.config/backup.conf" ]; then
    echo -e "  ${YELLOW}!${NC} No backup configuration found"
    echo -e "    ${GRAY}Important: Set up backups before major system changes${NC}"
    echo -e "    ${GRAY}Your home directory will be empty on fresh installations${NC}"
fi