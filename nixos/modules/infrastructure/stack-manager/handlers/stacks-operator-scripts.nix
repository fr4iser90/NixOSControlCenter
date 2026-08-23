# Script derivations for fleet-tags + dns-env (imported by commands.nix, not as NixOS module).
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
  virtUser =
    if hasVirtUsers then (lib.head (lib.attrNames virtUsers))
    else if (hasAdminUsers && !isSwarmMode) then (lib.head (lib.attrNames adminUsers))
    else null;

  installRoot = cfg.catalog.installRoot or "";
  fleetTagsJson = builtins.toJSON (cfg.fleetTags or {});

  dnsEmail = cfg.dns.cloudflare.apiEmail or "";
  dnsToken = cfg.dns.cloudflare.apiToken or "";

  stacksFleetTags = pkgs.writeShellScriptBin "ncc-stacks-fleet-tags" ''
    set -euo pipefail
    ${pkgs.jq}/bin/jq -n --argjson fleetTags '${fleetTagsJson}' '{ fleetTags: $fleetTags }'
  '';

  stacksDnsEnv = pkgs.writeShellScriptBin "ncc-stacks-dns-env" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    VIRT_USER=${lib.escapeShellArg (if virtUser == null then "" else virtUser)}
    INSTALL_ROOT=${lib.escapeShellArg installRoot}
    CF_EMAIL=""
    CF_TOKEN=""
    JSON_IN=""

    for a in "$@"; do
      case "$a" in
        --cf-email=*) CF_EMAIL="''${a#*=}" ;;
        --cf-token=*) CF_TOKEN="''${a#*=}" ;;
        --json) JSON_IN="stdin" ;;
        -h|--help|help)
          cat <<EOF
ncc stacks dns-env — write gateway/ddns-updater/ddns-updater.env (Cloudflare)

Usage:
  sudo -u <virt-user> ncc stacks dns-env --cf-email=MAIL --cf-token=TOKEN
  ncc stacks dns-env --json   # {"cfEmail":"…","cfToken":"…"}

Writes catalog/gateway/ddns-updater/ddns-updater.env under the virt home.
EOF
          exit 0
          ;;
      esac
    done

    if [[ "$JSON_IN" == "stdin" ]]; then
      JSON=$(cat)
      CF_EMAIL=$(echo "$JSON" | ${pkgs.jq}/bin/jq -r '.cfEmail // .cloudflare.apiEmail // empty')
      CF_TOKEN=$(echo "$JSON" | ${pkgs.jq}/bin/jq -r '.cfToken // .cloudflare.apiToken // empty')
    fi

    if [[ -z "$CF_EMAIL" && -n ${lib.escapeShellArg dnsEmail} ]]; then
      CF_EMAIL=${lib.escapeShellArg dnsEmail}
    fi
    if [[ -z "$CF_TOKEN" && -n ${lib.escapeShellArg dnsToken} ]]; then
      CF_TOKEN=${lib.escapeShellArg dnsToken}
    fi

    if [[ -z "$VIRT_USER" ]]; then
      ${ui.messages.error "No virtualization/admin user configured"}
      exit 1
    fi
    if [[ "$(whoami)" != "$VIRT_USER" ]]; then
      ${ui.messages.error "Run as $VIRT_USER (e.g. sudo -u $VIRT_USER ncc stacks dns-env …)"}
      exit 1
    fi
    if [[ -z "$CF_EMAIL" || -z "$CF_TOKEN" ]]; then
      ${ui.messages.error "Need --cf-email and --cf-token (or --json)"}
      exit 1
    fi

    BASE="/home/$VIRT_USER"
    [[ -n "$INSTALL_ROOT" ]] && BASE="$BASE/$INSTALL_ROOT"
    ENV_FILE="$BASE/catalog/gateway/ddns-updater/ddns-updater.env"
    mkdir -p "$(dirname "$ENV_FILE")"

    ${ui.messages.loading "Writing DNS env for Cloudflare…"}
    cat > "$ENV_FILE" <<EOF
DNS_PROVIDER_CODE=cloudflare
CF_API_EMAIL=$CF_EMAIL
CF_TOKEN=$CF_TOKEN
CLOUDFLARE_EMAIL=$CF_EMAIL
CLOUDFLARE_DNS_API_TOKEN=$CF_TOKEN
EOF
    ${ui.messages.success "Wrote $ENV_FILE"}
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.messages.info "Next: ncc stacks init --profile homelab-core"}
    fi
  '';
in {
  inherit stacksFleetTags stacksDnsEnv;
}
