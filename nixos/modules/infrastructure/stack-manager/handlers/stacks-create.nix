{ config, lib, pkgs, systemConfig, getModuleConfig, isSwarmMode, ... }:

let
  cfg = getModuleConfig "stack-manager";

  virtUsers = lib.filterAttrs
    (name: user: user.role == "virtualization")
    (getModuleConfig "user");
  adminUsers = lib.filterAttrs
    (name: user: user.role == "admin")
    (getModuleConfig "user");

  hasVirtUsers = (lib.length (lib.attrNames virtUsers)) > 0;
  hasAdminUsers = (lib.length (lib.attrNames adminUsers)) > 0;

  virtUser = if hasVirtUsers then (lib.head (lib.attrNames virtUsers))
    else if (hasAdminUsers && !isSwarmMode) then (lib.head (lib.attrNames adminUsers))
    else null;

  profiles = cfg.profiles or [];
  profileArgs = lib.concatMapStringsSep " " (p: "--profile ${lib.escapeShellArg p}") profiles;
  installRoot = cfg.catalog.installRoot or "";

  stacks-create = pkgs.writeScriptBin "ncc-stacks-init" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    VIRT_USER=${lib.escapeShellArg (if virtUser == null then "" else virtUser)}
    INSTALL_ROOT=${lib.escapeShellArg installRoot}
    CONFIG_PROFILES=( ${lib.concatMapStringsSep " " (p: lib.escapeShellArg p) profiles} )

    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    NC='\033[0m'

    if [[ -z "$VIRT_USER" ]]; then
      echo -e "''${RED}Error: no virtualization/admin user configured''${NC}"
      exit 1
    fi
    if [[ "$(whoami)" != "$VIRT_USER" ]]; then
      echo -e "''${RED}Error: run as $VIRT_USER''${NC}"
      exit 1
    fi

    BASE="/home/$VIRT_USER"
    [[ -n "$INSTALL_ROOT" ]] && BASE="$BASE/$INSTALL_ROOT"
    SCRIPTS="$BASE/docker-scripts/bin"

    if [[ ! -d "$BASE/catalog" || ! -d "$SCRIPTS" ]]; then
      echo -e "''${RED}Catalog not found under $BASE''${NC}"
      echo -e "''${YELLOW}Run: ncc stacks fetch''${NC}"
      exit 1
    fi

    # Pass-through CLI args; if none and config has profiles, use those
    EXTRA=("$@")
    if [[ ''${#EXTRA[@]} -eq 0 && ''${#CONFIG_PROFILES[@]} -gt 0 ]]; then
      for p in "''${CONFIG_PROFILES[@]}"; do
        EXTRA+=(--profile "$p")
      done
    fi

    # Detect family from first --profile
    FAMILY="homelab"
    for ((i=0; i<''${#EXTRA[@]}; i++)); do
      if [[ "''${EXTRA[$i]}" == "--profile" || "''${EXTRA[$i]}" == "-p" ]]; then
        pname="''${EXTRA[$((i+1))]:-}"
        if [[ "$pname" == compute-* ]]; then
          FAMILY="compute"
        fi
      fi
    done

    USER_UID=$(id -u)
    USER_GID=$(id -g)
    export USER_UID USER_GID
    export DOMAIN=${lib.escapeShellArg (systemConfig.domain or "")}
    export EMAIL=${lib.escapeShellArg (systemConfig.email or "")}

    # Substitute placeholders in yml/env under catalog
    if [[ -d "$BASE/catalog" ]]; then
      echo -e "''${YELLOW}Updating placeholders in catalog…''${NC}"
      find "$BASE/catalog" -type f \( -name "*.yml" -o -name "*.yaml" -o -name "*.env" \) \
        -exec sed -i \
          -e "s|{{EMAIL}}|$EMAIL|g" \
          -e "s|{{DOMAIN}}|$DOMAIN|g" \
          -e "s|{{USER}}|$VIRT_USER|g" \
          -e "s|{{UID}}|$USER_UID|g" \
          -e "s|{{GID}}|$USER_GID|g" \
          {} \;
    fi

    if [[ "$FAMILY" == "compute" ]]; then
      INIT="$SCRIPTS/init-compute.sh"
    else
      INIT="$SCRIPTS/init-homelab.sh"
    fi

    if [[ ! -f "$INIT" ]]; then
      echo -e "''${RED}Missing $INIT''${NC}"
      exit 1
    fi

    echo -e "''${YELLOW}Running $(basename "$INIT") ''${EXTRA[*]}…''${NC}"
    bash "$INIT" "''${EXTRA[@]}"
    echo -e "''${GREEN}Stack init finished''${NC}"
  '';

  # Back-compat
  homelab-create = pkgs.writeScriptBin "homelab-create" ''
    #!${pkgs.bash}/bin/bash
    exec ${stacks-create}/bin/ncc-stacks-init "$@"
  '';
in {
  config = lib.mkIf (hasVirtUsers || hasAdminUsers) {
    environment.systemPackages = [ stacks-create homelab-create ];
  };
}
