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
groups=$(groups)
echo -e "  Groups   : ${GRAY}${groups}${NC}"

# Wichtige Gruppen prüfen
important_groups=("wheel" "audio" "video" "input" "networkmanager")
missing_groups=()
for group in "${important_groups[@]}"; do
    if ! groups | grep -q "\b${group}\b"; then
        missing_groups+=("$group")
    fi
done

if [ ${#missing_groups[@]} -gt 0 ]; then
    echo -e "  ${YELLOW}Missing recommended groups: ${missing_groups[*]}${NC}"
fi

# Konfigurationspfade prüfen
log_info "Configuration Paths:"

# NixOS Konfiguration
check_path "/etc/nixos/configuration.nix" "NixOS Config"

# Home-Manager Konfigurationen (verschiedene mögliche Pfade)
hm_paths=(
    "$current_home/.config/home-manager/home.nix"
    "$current_home/.config/nixpkgs/home.nix"
    "$current_home/.nixpkgs/home.nix"
)

hm_found=false
for path in "${hm_paths[@]}"; do
    if check_path "$path" "Home Manager"; then
        hm_found=true
        break
    fi
done

# Flake Konfigurationen
flake_paths=(
    "/etc/nixos/flake.nix"
    "$current_home/.config/nixos/flake.nix"
    "$current_home/.nixos/flake.nix"
)

flake_found=false
for path in "${flake_paths[@]}"; do
    if check_path "$path" "Flake Config"; then
        flake_found=true
        break
    fi
done

# Prüfe Home-Manager Installation
log_info "Home Manager Status:"
if command -v home-manager &> /dev/null; then
    hm_version=$(home-manager --version 2>/dev/null || echo "unknown")
    echo -e "  Status   : ${GREEN}Installed${NC} (${GRAY}${hm_version}${NC})"
    
    # Prüfe Home-Manager Generation
    if [ -L "$current_home/.local/state/home-manager/gcroots/current-home" ]; then
        echo -e "  Profile  : ${GREEN}Active${NC}"
    else
        echo -e "  Profile  : ${YELLOW}Not activated${NC}"
    fi
else
    echo -e "  Status   : ${YELLOW}Not installed${NC}"
fi

# Shell-Konfiguration
log_info "Shell Configuration:"
current_shell=$(getent passwd $current_user | cut -d: -f7)
echo -e "  Shell    : ${CYAN}${current_shell}${NC}"

# Prüfe wichtige Dotfiles
log_info "Important Dotfiles:"
dotfiles=(".profile" ".bashrc" ".zshrc" ".config/fish/config.fish")
for file in "${dotfiles[@]}"; do
    check_path "$current_home/$file" "${file}"
done

# Zusammenfassung
log_info "Summary:"
if $hm_found; then
    echo -e "  ${GREEN}✓${NC} Home Manager configuration found"
else
    echo -e "  ${YELLOW}!${NC} No Home Manager configuration found"
fi

if $flake_found; then
    echo -e "  ${GREEN}✓${NC} Flake configuration found"
else
    echo -e "  ${YELLOW}!${NC} No Flake configuration found"
fi

if [ ${#missing_groups[@]} -eq 0 ]; then
    echo -e "  ${GREEN}✓${NC} All recommended groups present"
else
    echo -e "  ${YELLOW}!${NC} Some recommended groups missing"
fi