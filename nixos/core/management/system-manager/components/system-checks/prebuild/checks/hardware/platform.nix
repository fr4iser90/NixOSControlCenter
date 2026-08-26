{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

let
  cliRegistry = getModuleApi "cli-registry";
  ui = getModuleApi "cli-formatter";
  facade = import ../../../../../lib/config-facade.nix { inherit pkgs; };
  layout = (getModuleConfig "system-manager").layout or "monolith";
  preflightRemote = import ../../../../lib/preflight-remote.nix { inherit getModuleApi; };

  prebuildScript = pkgs.writeScriptBin "prebuild-check-platform" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    ${facade.sourcePreamble {
      nixosRoot = "/etc/nixos";
      inherit layout;
    }}

    ${preflightRemote.bashHelpers}

    VERBOSE="''${NCC_PREFLIGHT_VERBOSE:-0}"

    _detect_platform() {
      local machine
      machine="$(uname -m 2>/dev/null || true)"
      case "$machine" in
        x86_64|amd64) printf '%s\n' "x86_64-linux" ;;
        aarch64|arm64) printf '%s\n' "aarch64-linux" ;;
        *)
          printf '%s\n' ""
          return 1
          ;;
      esac
    }

    _configured_platform() {
      local current
      current=$(ncc_read_module_config "core/management/system-manager" 2>/dev/null || echo "{}")
      # Prefer dotted system.platform; else nested platform = inside system = { }
      if echo "$current" | grep -qE 'system\.platform[[:space:]]*='; then
        echo "$current" | grep -oE 'system\.platform[[:space:]]*=[[:space:]]*"[^"]*"' | head -1 | cut -d'"' -f2
        return 0
      fi
      if echo "$current" | grep -qE '^[[:space:]]*platform[[:space:]]*='; then
        echo "$current" | grep -E '^[[:space:]]*platform[[:space:]]*=' | head -1 | cut -d'"' -f2
        return 0
      fi
      printf '%s\n' ""
    }

    _update_platform() {
      local new_value="$1"
      local current
      current=$(ncc_read_module_config "core/management/system-manager" 2>/dev/null || echo "{}")

      if echo "$current" | grep -qE 'system\.platform[[:space:]]*='; then
        current=$(echo "$current" | sed -E "s/system\.platform[[:space:]]*=[[:space:]]*\"[^\"]*\"/system.platform = \"$new_value\"/")
      elif echo "$current" | grep -qE '^[[:space:]]*platform[[:space:]]*='; then
        current=$(echo "$current" | sed -E "s/(^[[:space:]]*platform[[:space:]]*=[[:space:]]*)\"[^\"]*\"/\1\"$new_value\"/")
      elif echo "$current" | grep -qE 'system\.channel[[:space:]]*='; then
        current=$(echo "$current" | sed -E "s/(system\.channel[[:space:]]*=[[:space:]]*\"[^\"]*\"[[:space:]]*;)/\1\n  system.platform = \"$new_value\";/")
      elif echo "$current" | grep -qE '^[[:space:]]*channel[[:space:]]*='; then
        current=$(echo "$current" | sed -E "s/(^[[:space:]]*channel[[:space:]]*=[[:space:]]*\"[^\"]*\"[[:space:]]*;)/\1\n    platform = \"$new_value\";/")
      elif echo "$current" | grep -qE 'system[[:space:]]*=[[:space:]]*\{'; then
        current=$(echo "$current" | ${pkgs.gnused}/bin/sed -E "0,/system[[:space:]]*=[[:space:]]*\{/s//system = {\n    platform = \"$new_value\";/")
      elif echo "$current" | grep -qE 'systemType[[:space:]]*='; then
        current=$(echo "$current" | sed -E "s/(systemType[[:space:]]*=[[:space:]]*\"[^\"]*\"[[:space:]]*;)/\1\n  system.platform = \"$new_value\";/")
      elif [ "$current" = "{}" ] || [ -z "$(echo "$current" | tr -d '[:space:]{}')" ]; then
        current="{
  configVersion = \"2.1\";
  layout = \"monolith\";
  systemType = \"desktop\";
  system.platform = \"$new_value\";
}"
      else
        current=$(printf '%s\n' "$current" | ${pkgs.gnused}/bin/sed "\$ i\  system.platform = \"$new_value\";")
      fi

      ncc_write_module_config "core/management/system-manager" "$current"
    }

    DETECTED="$(_detect_platform)" || {
      ${ui.badges.error "Platform: could not detect (uname -m)"}
      exit 1
    }

    CONFIGURED="$(_configured_platform)"

    if [ "$VERBOSE" = "1" ]; then
      echo "  detected:   $DETECTED"
      echo "  configured: ''${CONFIGURED:-(unset)}"
    fi

    _ncc_preflight_compare_only "Platform" "$CONFIGURED" "$DETECTED"

    if [ -z "$CONFIGURED" ]; then
      _update_platform "$DETECTED"
      ${ui.badges.warning "Platform: was unset → set to $DETECTED"}
      ${ui.badges.success "Platform: $DETECTED"}
      exit 0
    fi

    if [ "$DETECTED" != "$CONFIGURED" ]; then
      ${ui.badges.warning "Platform: was $CONFIGURED → set to $DETECTED"}
      _update_platform "$DETECTED"
      ${ui.badges.success "Platform: $DETECTED"}
    else
      ${ui.badges.success "Platform: $DETECTED"}
    fi

    exit 0
  '';

in {
  config = lib.mkMerge [
    {
      environment.systemPackages = [ prebuildScript ];
    }
    (cliRegistry.registerCommandsFor "system-checks-platform" [
      {
        name = "check-platform";
        domain = "system";
        category = "system-checks";
        internal = true;
        description = "Check CPU architecture / nixpkgs platform before rebuild";
        script = "${prebuildScript}/bin/prebuild-check-platform";
        shortHelp = "check-platform - Sync system.platform with live uname -m";
        longHelp = ''
          Detect host arch (x86_64-linux / aarch64-linux) and write
          system-manager.system.platform like CPU/GPU preflight (overwrite on mismatch).
          Quiet by default; details with NCC_PREFLIGHT_VERBOSE=1.
        '';
        interactive = false;
        dependencies = [ "system-checks" ];
      }
    ])
  ];
}
