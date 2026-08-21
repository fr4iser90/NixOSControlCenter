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

  repoUrl = cfg.catalog.repoUrl or "https://github.com/fr4iser90/NCC-Stacks.git";
  repoRef = cfg.catalog.ref or "main";
  installRoot = cfg.catalog.installRoot or "";

  stacks-fetch = pkgs.writeScriptBin "ncc-stacks-fetch" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    REPO_URL=${lib.escapeShellArg repoUrl}
    REPO_REF=${lib.escapeShellArg repoRef}
    VIRT_USER=${lib.escapeShellArg (if virtUser == null then "" else virtUser)}
    INSTALL_ROOT=${lib.escapeShellArg installRoot}
    TEMP_DIR="/tmp/ncc-stacks-fetch"

    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.text.header "Stacks fetch"}
    fi

    if [[ -z "$VIRT_USER" ]]; then
      ${ui.messages.error "No virtualization/admin user configured"}
      exit 1
    fi
    if [[ "$(whoami)" != "$VIRT_USER" ]]; then
      ${ui.messages.error "Run as $VIRT_USER (e.g. sudo -u $VIRT_USER ncc stacks fetch)"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: sudo -u $VIRT_USER ncc stacks fetch"}
      fi
      exit 1
    fi

    DEST="/home/$VIRT_USER"
    if [[ -n "$INSTALL_ROOT" ]]; then
      DEST="$DEST/$INSTALL_ROOT"
      mkdir -p "$DEST"
    fi

    ${ui.messages.loading "Fetching stack catalog…"}
    ${ui.tables.keyValue "Repo" "$REPO_URL ($REPO_REF)"}
    ${ui.tables.keyValue "Dest" "$DEST"}
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"

    if ! git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$TEMP_DIR"; then
      ${ui.messages.error "Failed to clone repository"}
      exit 1
    fi

    # Prefer rsync so we refresh catalog/ docker-scripts/ profiles/ without wiping unrelated home files
    if command -v rsync >/dev/null 2>&1; then
      rsync -a --delete \
        --exclude '.git' \
        "$TEMP_DIR"/catalog "$TEMP_DIR"/docker-scripts "$TEMP_DIR"/profiles \
        "$TEMP_DIR"/docs "$TEMP_DIR"/tests "$TEMP_DIR"/README.md \
        "$DEST"/ 2>/dev/null || {
        # Fallback: copy known trees
        for d in catalog docker-scripts profiles docs tests; do
          [[ -d "$TEMP_DIR/$d" ]] && rm -rf "$DEST/$d" && cp -a "$TEMP_DIR/$d" "$DEST/"
        done
        [[ -f "$TEMP_DIR/README.md" ]] && cp -a "$TEMP_DIR/README.md" "$DEST/"
      }
    else
      for d in catalog docker-scripts profiles docs tests; do
        [[ -d "$TEMP_DIR/$d" ]] && rm -rf "$DEST/$d" && cp -a "$TEMP_DIR/$d" "$DEST/"
      done
      [[ -f "$TEMP_DIR/README.md" ]] && cp -a "$TEMP_DIR/README.md" "$DEST/"
    fi

    find "$DEST/catalog" "$DEST/docker-scripts" "$DEST/profiles" -type d -exec chmod 755 {} \; 2>/dev/null || true
    find "$DEST/docker-scripts" -type f -name '*.sh' -exec chmod 755 {} \; 2>/dev/null || true

    rm -rf "$TEMP_DIR"
    ${ui.messages.success "Stack catalog fetch completed"}
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.messages.info "Next: ncc stacks init --profile <name>"}
    fi
  '';

  # Back-compat name
  homelab-fetch = pkgs.writeScriptBin "homelab-fetch" ''
    #!${pkgs.bash}/bin/bash
    exec ${stacks-fetch}/bin/ncc-stacks-fetch "$@"
  '';
in {
  config = lib.mkIf ((cfg.enable or false) && (hasVirtUsers || hasAdminUsers)) {
    environment.systemPackages = [ stacks-fetch homelab-fetch ];
  };
}
