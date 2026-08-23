{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

let
  cfg = getModuleConfig "stack-manager";
  ui = getModuleApi "cli-formatter";
  isSwarmMode = (cfg.swarm or null) != null;

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
  dnsEnabled = cfg.dns.enable or false;
  dnsEmail = cfg.dns.cloudflare.apiEmail or "";
  dnsToken = cfg.dns.cloudflare.apiToken or "";

  stacks-create = pkgs.writeScriptBin "ncc-stacks-init" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    VIRT_USER=${lib.escapeShellArg (if virtUser == null then "" else virtUser)}
    INSTALL_ROOT=${lib.escapeShellArg installRoot}
    CONFIG_PROFILES=( ${lib.concatMapStringsSep " " (p: lib.escapeShellArg p) profiles} )

    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.text.header "Stacks init"}
    fi

    if [[ -z "$VIRT_USER" ]]; then
      ${ui.messages.error "No virtualization/admin user configured"}
      exit 1
    fi
    if [[ "$(whoami)" != "$VIRT_USER" ]]; then
      ${ui.messages.error "Run as $VIRT_USER"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: sudo -u $VIRT_USER ncc stacks init"}
      fi
      exit 1
    fi

    BASE="/home/$VIRT_USER"
    [[ -n "$INSTALL_ROOT" ]] && BASE="$BASE/$INSTALL_ROOT"
    SCRIPTS="$BASE/docker-scripts/bin"

    if [[ ! -d "$BASE/catalog" || ! -d "$SCRIPTS" ]]; then
      ${ui.messages.error "Catalog not found under $BASE"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: ncc stacks fetch"}
      fi
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

    DNS_ENV_FILE="$BASE/catalog/gateway/ddns-updater/ddns-updater.env"
    DNS_CFG_ENABLE=${if dnsEnabled then "true" else "false"}
    DNS_CFG_EMAIL=${lib.escapeShellArg dnsEmail}
    DNS_CFG_TOKEN=${lib.escapeShellArg dnsToken}
    if [[ "$DNS_CFG_ENABLE" == "true" && -n "$DNS_CFG_EMAIL" && -n "$DNS_CFG_TOKEN" ]]; then
      mkdir -p "$(dirname "$DNS_ENV_FILE")"
      cat > "$DNS_ENV_FILE" <<EOF
DNS_PROVIDER_CODE=cloudflare
CF_API_EMAIL=$DNS_CFG_EMAIL
CF_TOKEN=$DNS_CFG_TOKEN
CLOUDFLARE_EMAIL=$DNS_CFG_EMAIL
CLOUDFLARE_DNS_API_TOKEN=$DNS_CFG_TOKEN
EOF
      export NCC_NON_INTERACTIVE=1
      export NCC_ASSUME_YES=1
    elif [[ -f "$DNS_ENV_FILE" ]] && grep -q '^DNS_PROVIDER_CODE=' "$DNS_ENV_FILE" 2>/dev/null; then
      export NCC_NON_INTERACTIVE=1
      export NCC_ASSUME_YES=1
    fi

    # Substitute placeholders in yml/env under catalog
    if [[ -d "$BASE/catalog" ]]; then
      ${ui.messages.loading "Updating placeholders in catalog…"}
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
      ${ui.messages.error "Missing $INIT"}
      exit 1
    fi

    ${ui.messages.loading ''Running $(basename "$INIT") ''${EXTRA[*]}…''}
    ${ui.tables.keyValue "Family" "$FAMILY"}
    ${ui.tables.keyValue "Script" "$INIT"}
    bash "$INIT" "''${EXTRA[@]}"
    ${ui.messages.success "Stack init finished"}
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.messages.info "Next: ncc stacks status   or   ncc stacks ops status"}
    fi
  '';

  # Back-compat
  homelab-create = pkgs.writeScriptBin "homelab-create" ''
    #!${pkgs.bash}/bin/bash
    exec ${stacks-create}/bin/ncc-stacks-init "$@"
  '';
in {
  config = lib.mkIf ((cfg.enable or false) && (hasVirtUsers || hasAdminUsers)) {
    environment.systemPackages = [ stacks-create homelab-create ];
  };
}
