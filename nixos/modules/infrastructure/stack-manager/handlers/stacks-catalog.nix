{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

# Catalog browse + install helpers (formatter SSOT).
# List can use: local virt/admin home, NCC_STACKS_ROOT, or --remote ephemeral clone (no fetch into home).
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
    else "";

  repoUrl = cfg.catalog.repoUrl or "https://github.com/fr4iser90/NCC-Stacks.git";
  repoRef = cfg.catalog.ref or "main";
  installRoot = cfg.catalog.installRoot or "";

  resolveCatalogRoot = ''
    VIRT_USER=${lib.escapeShellArg virtUser}
    INSTALL_ROOT=${lib.escapeShellArg installRoot}
    REPO_URL=${lib.escapeShellArg repoUrl}
    REPO_REF=${lib.escapeShellArg repoRef}
    REMOTE=false
    VERBOSE=false
    SHOW_ALL=false
    FAMILY_FILTER=""
    _ncc_browse_tmp=""

    ncc_host_arch() {
      case "$(uname -m)" in
        aarch64|arm64) echo "aarch64" ;;
        x86_64|amd64) echo "x86_64" ;;
        *) uname -m ;;
      esac
    }

    ncc_profile_field() {
      local file="$1" key="$2"
      grep -E "^''${key}:" "$file" 2>/dev/null | head -1 \
        | sed -E "s/^''${key}:[[:space:]]*//" | tr -d '"' | tr -d "'"
    }

    ncc_arch_ok() {
      local file="$1" want have
      want=$(ncc_profile_field "$file" "arch" | tr '[:upper:]' '[:lower:]')
      case "$want" in
        ""|any|"*"|all|neutral) return 0 ;;
      esac
      have=$(ncc_host_arch)
      [[ "$want" == "$have" ]]
    }

    ncc_cleanup_browse() {
      if [[ -n "''${_ncc_browse_tmp:-}" && -d "$_ncc_browse_tmp" ]]; then
        rm -rf "$_ncc_browse_tmp"
      fi
    }

    ncc_resolve_catalog_root() {
      if [[ -n "''${NCC_STACKS_ROOT:-}" && -d "''${NCC_STACKS_ROOT}/profiles" && -d "''${NCC_STACKS_ROOT}/catalog" ]]; then
        CATALOG_ROOT="$NCC_STACKS_ROOT"
        CATALOG_SOURCE="NCC_STACKS_ROOT"
        return 0
      fi
      if [[ -n "$VIRT_USER" ]]; then
        local base="/home/$VIRT_USER"
        [[ -n "$INSTALL_ROOT" ]] && base="$base/$INSTALL_ROOT"
        if [[ -d "$base/profiles" && -d "$base/catalog" ]]; then
          CATALOG_ROOT="$base"
          CATALOG_SOURCE="home:$VIRT_USER"
          return 0
        fi
      fi
      if [[ "$REMOTE" == true ]]; then
        _ncc_browse_tmp=$(mktemp -d /tmp/ncc-stacks-browse.XXXXXX)
        trap ncc_cleanup_browse EXIT
        ${ui.messages.loading "Cloning catalog for browse (ephemeral)…"}
        if ! git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$_ncc_browse_tmp" >/dev/null 2>&1; then
          ${ui.messages.error "Could not clone $REPO_URL ($REPO_REF)"}
          return 1
        fi
        CATALOG_ROOT="$_ncc_browse_tmp"
        CATALOG_SOURCE="remote:$REPO_URL@$REPO_REF"
        return 0
      fi
      ${ui.messages.error "No local catalog found"}
      ${ui.messages.info "Next: ncc stacks fetch   or   NCC_STACKS_ROOT=/path/to/NCC-Stacks   or   add --remote"}
      return 1
    }
  '';

  listProfiles = pkgs.writeShellScriptBin "ncc-stacks-list-profiles" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    ${resolveCatalogRoot}

    for a in "$@"; do
      case "$a" in
        --remote|-r) REMOTE=true ;;
        --all|-a) SHOW_ALL=true ;;
        --verbose|-v) VERBOSE=true ;;
        --help|-h)
          echo "Usage: ncc stacks list-profiles [--remote] [--all] [-v]"
          echo "  Default: only profiles compatible with this host arch"
          echo "  --all    include arch-mismatched (marked)"
          echo "  --remote ephemeral clone (no fetch into virt home)"
          exit 0
          ;;
      esac
    done

    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.text.header "Stack profiles"}
    fi

    ncc_resolve_catalog_root || exit 1
    HOST_ARCH=$(ncc_host_arch)
    ${ui.tables.keyValue "Host arch" "$HOST_ARCH"}
    ${ui.tables.keyValue "Catalog" "$CATALOG_SOURCE"}
    if [[ "$VERBOSE" == true ]]; then
      ${ui.tables.keyValue "Root" "$CATALOG_ROOT"}
    fi

    ${ui.messages.loading "Scanning profiles…"}
    count=0
    skipped=0
    while IFS= read -r f; do
      [ -f "$f" ] || continue
      name=$(basename "$f" .yml)
      family=$(ncc_profile_field "$f" "family")
      arch=$(ncc_profile_field "$f" "arch")
      [[ -z "$arch" ]] && arch="any"
      if ncc_arch_ok "$f"; then
        ${ui.badges.success "$name"}
        echo "         family=$family  arch=$arch"
        count=$((count + 1))
      else
        skipped=$((skipped + 1))
        if [[ "$SHOW_ALL" == true ]]; then
          ${ui.badges.warning "$name (arch=$arch — host $HOST_ARCH)"}
        elif [[ "$VERBOSE" == true ]]; then
          ${ui.messages.info "skip $name (arch=$arch)"}
        fi
      fi
    done < <(find "$CATALOG_ROOT/profiles" -maxdepth 1 -type f -name '*.yml' | sort)

    ${ui.messages.success "Profiles listed ($count compatible)"}
    if [[ "$VERBOSE" == true || "$SHOW_ALL" == true ]]; then
      ${ui.messages.info "Skipped (arch): $skipped"}
    fi
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.messages.info "Next: ncc stacks install --profile <name>   or   ncc stacks list-catalog"}
    fi
  '';

  listCatalog = pkgs.writeShellScriptBin "ncc-stacks-list-catalog" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    ${resolveCatalogRoot}

    _args=("$@")
    for ((i=0; i<''${#_args[@]}; i++)); do
      case "''${_args[$i]}" in
        --remote|-r) REMOTE=true ;;
        --verbose|-v) VERBOSE=true ;;
        --family=*) FAMILY_FILTER="''${_args[$i]#--family=}" ;;
        --family)
          FAMILY_FILTER="''${_args[$((i+1))]:-}"
          ;;
        --help|-h)
          echo "Usage: ncc stacks list-catalog [--remote] [--family homelab|compute] [-v]"
          echo "  Lists individual catalog services (group/service), not profile bundles"
          echo "  --remote ephemeral clone (no fetch into virt home)"
          exit 0
          ;;
      esac
    done

    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.text.header "Stack catalog"}
    fi

    ncc_resolve_catalog_root || exit 1
    ${ui.tables.keyValue "Catalog" "$CATALOG_SOURCE"}
    [[ -n "$FAMILY_FILTER" ]] && ${ui.tables.keyValue "Family filter" "$FAMILY_FILTER"}
    if [[ "$VERBOSE" == true ]]; then
      ${ui.tables.keyValue "Root" "$CATALOG_ROOT"}
      ${ui.tables.keyValue "Host arch" "$(ncc_host_arch)"}
    fi

    ${ui.messages.loading "Scanning catalog services…"}
    count=0
    while IFS= read -r dir; do
      [ -d "$dir" ] || continue
      rel="''${dir#"$CATALOG_ROOT/catalog/"}"
      base=$(basename "$dir")
      case "$base" in
        arm|cpu|rocm) continue ;;
      esac
      [[ "$rel" == */* ]] || continue
      [[ "$rel" == */*/* ]] && continue
      group="''${rel%%/*}"
      if [[ -n "$FAMILY_FILTER" ]]; then
        if [[ "$FAMILY_FILTER" == "compute" && "$group" != "compute" ]]; then
          continue
        fi
        if [[ "$FAMILY_FILTER" == "homelab" && "$group" == "compute" ]]; then
          continue
        fi
      fi
      if ! find "$dir" -maxdepth 2 \( -name 'compose.yaml' -o -name 'compose.yml' -o -name 'docker-compose.yml' -o -name 'docker-compose.yaml' -o -name 'docker-stack.yml' \) -print -quit | grep -q .; then
        continue
      fi
      variants=""
      for v in arm cpu rocm; do
        [[ -d "$dir/$v" ]] && variants="$variants$v "
      done
      ${ui.badges.success "$rel"}
      if [[ "$VERBOSE" == true && -n "$variants" ]]; then
        echo "         variants: $variants"
      fi
      count=$((count + 1))
    done < <(find "$CATALOG_ROOT/catalog" -mindepth 2 -maxdepth 2 -type d | sort)

    ${ui.messages.success "Catalog services listed ($count)"}
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.messages.info "Next: ncc stacks install <group/service>   or   ncc stacks install --profile <name>"}
    fi
  '';

  stacksInstall = pkgs.writeShellScriptBin "ncc-stacks-install" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    VIRT_USER=${lib.escapeShellArg virtUser}
    INSTALL_ROOT=${lib.escapeShellArg installRoot}

    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.text.header "Stacks install"}
    fi

    if [[ $# -eq 0 || "''${1:-}" == "--help" || "''${1:-}" == "-h" ]]; then
      echo "Usage:"
      echo "  ncc stacks install --profile NAME [NAME …]"
      echo "  ncc stacks install group/service [group/service …]"
      echo "Profiles = bundles; group/service = single catalog stack"
      exit 0
    fi

    if [[ -z "$VIRT_USER" ]]; then
      ${ui.messages.error "No virtualization/admin user configured"}
      exit 1
    fi

    BASE="/home/$VIRT_USER"
    [[ -n "$INSTALL_ROOT" ]] && BASE="$BASE/$INSTALL_ROOT"

    if [[ ! -d "$BASE/catalog" || ! -d "$BASE/docker-scripts/bin" ]]; then
      ${ui.messages.error "Catalog not installed under $BASE"}
      ${ui.messages.info "Next: sudo -u $VIRT_USER ncc stacks fetch"}
      exit 1
    fi

    if [[ "$(whoami)" != "$VIRT_USER" ]]; then
      ${ui.messages.error "Run as $VIRT_USER"}
      ${ui.messages.info "Next: sudo -u $VIRT_USER ncc stacks install …"}
      exit 1
    fi

    PROFILES=()
    SERVICES=()
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --profile|-p)
          shift
          if [[ -z "''${1:-}" ]]; then
            ${ui.messages.error "Missing profile name"}
            exit 1
          fi
          PROFILES+=("$1")
          shift
          ;;
        *)
          SERVICES+=("$1")
          shift
          ;;
      esac
    done

    if [[ ''${#PROFILES[@]} -gt 0 ]]; then
      ${ui.messages.loading "Installing profile(s)…"}
      ARGS=()
      for p in "''${PROFILES[@]}"; do
        ARGS+=(--profile "$p")
        ${ui.tables.keyValue "Profile" "$p"}
      done
      if command -v ncc-stacks-init >/dev/null 2>&1; then
        NCC_CLI_NESTED=1 ncc-stacks-init "''${ARGS[@]}"
      else
        ${ui.messages.error "ncc-stacks-init not on PATH"}
        exit 1
      fi
      ${ui.messages.success "Profile install finished"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: ncc stacks ops status"}
      fi
      exit 0
    fi

    if [[ ''${#SERVICES[@]} -eq 0 ]]; then
      ${ui.messages.error "Nothing to install"}
      exit 1
    fi

    ${ui.messages.loading "Starting catalog service(s)…"}
    for s in "''${SERVICES[@]}"; do
      ${ui.tables.keyValue "Service" "$s"}
    done
    bash "$BASE/docker-scripts/bin/stacks.sh" start "''${SERVICES[@]}"
    ${ui.messages.success "Service install/start finished"}
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.messages.info "Next: ncc stacks ops status   or   ncc stacks list-containers"}
    fi
  '';

in {
  config = lib.mkIf (cfg.enable or false) {
    environment.systemPackages = [
      listProfiles
      listCatalog
      stacksInstall
    ];
  };
}
