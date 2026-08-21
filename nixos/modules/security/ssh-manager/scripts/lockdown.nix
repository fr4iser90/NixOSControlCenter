{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getModuleMetadata, ... }:

with lib;

let
  ui = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry";
  cfg = getModuleConfig "ssh-manager";
  smRoot = (getModuleMetadata "system-manager").path;
  facade = import "${smRoot}/lib/config-facade.nix" { inherit pkgs; };
  hostname = lib.attrByPath [ "hostName" ] "nixos" (getModuleConfig "network");
  modulePath = "modules/security/ssh-manager";

  lockdownScript = pkgs.writeShellScriptBin "ncc-ssh-lockdown" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    FORCE=0
    DRY=0
    KEEP_ROOT=0
    for a in "$@"; do
      case "$a" in
        --force|-f) FORCE=1 ;;
        --dry-run) DRY=1 ;;
        --keep-root) KEEP_ROOT=1 ;;
        -h|--help)
          cat <<EOF
ncc ssh lockdown — turn off password SSH after keys work (daemon stays on)

Checks for authorized keys (and recent pubkey logins), then sets:
  passwordAuthentication = false
  permitRootLogin = "no"   (unless --keep-root)

Options:
  --force       Skip key / pubkey-login checks (dangerous)
  --dry-run     Show checks and planned config change only
  --keep-root   Leave permitRootLogin unchanged
  -h, --help    This help

After success: rebuild (e.g. sudo nixos-rebuild switch --flake /etc/nixos#${hostname})
Temporary reopen later: ncc ssh temp-open USER | ncc ssh grant-access USER
EOF
          exit 0
          ;;
        *)
          ${ui.messages.error "Unknown option: $a (try --help)"}
          exit 2
          ;;
      esac
    done

    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      if [[ "$DRY" -eq 1 ]]; then
        ${ui.text.header "SSH lockdown (dry-run)"}
        ${ui.messages.info "Preview only — nothing will be written under /etc/nixos"}
      else
        ${ui.text.header "SSH lockdown"}
      fi
    fi

    ${ui.messages.loading "Checking SSH key readiness for lockdown…"}

    KEY_HITS=0
    KEY_REPORT=""
    while IFS=: read -r user _ uid _ _ home _; do
      if [[ "$user" == "root" ]] || [[ "$uid" -ge 1000 ]]; then
        for f in \
          "$home/.ssh/authorized_keys" \
          "$home/.ssh/authorized_keys2" \
          "/etc/ssh/authorized_keys.d/$user"
        do
          if [[ -f "$f" ]] && grep -qE '^(ssh-|ecdsa-|sk-)' "$f" 2>/dev/null; then
            KEY_HITS=$((KEY_HITS + 1))
            KEY_REPORT="$KEY_REPORT
  - $user ← $f"
          fi
        done
      fi
    done < /etc/passwd

    # NixOS often stages keys under authorized_keys.d even without matching passwd home scan
    if [[ -d /etc/ssh/authorized_keys.d ]]; then
      while IFS= read -r -d "" f; do
        if grep -qE '^(ssh-|ecdsa-|sk-)' "$f" 2>/dev/null; then
          base=$(basename "$f")
          if ! echo "$KEY_REPORT" | grep -q "$f"; then
            KEY_HITS=$((KEY_HITS + 1))
            KEY_REPORT="$KEY_REPORT
  - $base ← $f"
          fi
        fi
      done < <(find /etc/ssh/authorized_keys.d -type f -print0 2>/dev/null)
    fi

    PUBKEY_LOGINS=0
    if journalctl -u sshd --since "30 days ago" -o cat 2>/dev/null \
         | grep -q "Accepted publickey"; then
      PUBKEY_LOGINS=1
    fi
    # Unit name may be ssh on some systems
    if [[ "$PUBKEY_LOGINS" -eq 0 ]]; then
      if journalctl -u ssh --since "30 days ago" -o cat 2>/dev/null \
           | grep -q "Accepted publickey"; then
        PUBKEY_LOGINS=1
      fi
    fi

    ${ui.tables.keyValue "Authorized key files" "$KEY_HITS"}
    if [[ -n "$KEY_REPORT" ]]; then
      echo "$KEY_REPORT"
    fi
    if [[ "$PUBKEY_LOGINS" -eq 1 ]]; then
      ${ui.tables.keyValue "Recent pubkey login" "yes (journal)"}
    else
      ${ui.tables.keyValue "Recent pubkey login" "not seen in last 30d"}
    fi

    if [[ "$FORCE" -ne 1 ]]; then
      if [[ "$KEY_HITS" -lt 1 ]]; then
        ${ui.messages.error "No authorized keys found. Add a key first, then retry."}
        if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
          ${ui.messages.info "Next: add a key, or re-run with --force if you have console access"}
        fi
        exit 1
      fi
      if [[ "$PUBKEY_LOGINS" -ne 1 ]]; then
        ${ui.messages.error "No recent successful publickey SSH login in the journal."}
        if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
          ${ui.messages.info "Next: log in once with your key, then re-run (or pass --force)"}
        fi
        exit 1
      fi
    else
      ${ui.messages.info "--force: skipping key / pubkey-login checks"}
    fi

    ${facade.sourcePreamble { nixosRoot = "/etc/nixos"; }}

    CURRENT=$(ncc_read_module_config "${modulePath}")
    if [[ -z "$CURRENT" || "$CURRENT" == "{}" ]]; then
      CURRENT='{ enable = true; }'
    fi

    LEAF_JSON=$(_ncc_eval_nix_to_json "$CURRENT") || {
      ${ui.messages.error "Could not parse ssh-manager config as Nix"}
      exit 1
    }

    if [[ "$KEEP_ROOT" -eq 1 ]]; then
      MERGED=$(echo "$LEAF_JSON" | ${pkgs.jq}/bin/jq -c \
        '.enable = true | .passwordAuthentication = false')
    else
      MERGED=$(echo "$LEAF_JSON" | ${pkgs.jq}/bin/jq -c \
        '.enable = true | .passwordAuthentication = false | .permitRootLogin = "no"')
    fi

    TMP_JSON=$(mktemp --suffix=.json)
    printf '%s\n' "$MERGED" > "$TMP_JSON"
    NEW_NIX=$(_ncc_json_to_nix "$TMP_JSON") || {
      rm -f "$TMP_JSON"
      ${ui.messages.error "Failed to serialize updated config"}
      exit 1
    }
    rm -f "$TMP_JSON"

    ${ui.messages.info "Planned config (${modulePath}):"}
    echo "$NEW_NIX"

    if [[ "$DRY" -eq 1 ]]; then
      ${ui.messages.success "Dry-run only — no files written"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: sudo ncc ssh lockdown"}
      fi
      exit 0
    fi

    if [[ "''${EUID:-$(id -u)}" -ne 0 ]]; then
      ${ui.messages.error "Writing systemConfig needs root. Re-run with sudo."}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: sudo ncc ssh lockdown"}
      fi
      exit 1
    fi

    ncc_write_module_config "${modulePath}" "$NEW_NIX"
    ${ui.messages.success "ssh-manager: passwordAuthentication=false (daemon stays enabled)"}
    if [[ "$KEEP_ROOT" -ne 1 ]]; then
      ${ui.messages.success "permitRootLogin set to \"no\""}
    fi
    if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
      ${ui.messages.info "Next: sudo nixos-rebuild switch --flake /etc/nixos#${hostname}"}
    fi
  '';
in {
  config = lib.mkMerge [
    {
      environment.systemPackages = [ lockdownScript ];
    }
    (cliRegistry.registerCommandsFor "ssh-server-lockdown" [
      {
        name = "lockdown";
        parent = "ssh";
        domain = "ssh";
        description = "Disable password SSH after keys work (guided)";
        category = "security";
        script = "${lockdownScript}/bin/ncc-ssh-lockdown";
        arguments = [ "[--force|--dry-run|--keep-root]" ];
        dependencies = [ "openssh" ];
        shortHelp = "lockdown - Disable password auth after pubkey works";
        longHelp = ''
          Checks for authorized keys and a recent publickey login, then sets
          passwordAuthentication = false (and permitRootLogin = "no") in
          ssh-manager config. OpenSSH daemon stays enabled.

          Usage: ncc ssh lockdown [--dry-run] [--force] [--keep-root]
        '';
      }
    ])
  ];
}
