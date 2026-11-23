{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

let
  cliRegistry = getModuleApi "cli-registry";
  ui = getModuleApi "cli-formatter";
  facade = import ../../../../../lib/config-facade.nix { inherit pkgs; };

  smCfg = getModuleConfig "system-manager";
  pkgCfg = getModuleConfig "packages";
  systemType = smCfg.systemType or "desktop";
  packageModules = pkgCfg.packageModules or [];
  dockerEnable = pkgCfg.docker.enable or false;
  hasDocker =
    lib.elem "docker" packageModules
    || lib.elem "docker-rootless" packageModules
    || dockerEnable;
  packagesEmpty = packageModules == [] && !dockerEnable;

  # Homelab expectation: at least root Docker (Swarm-capable). Full recipe stays wizard/opt-in.
  seedContent = ''
    {
      packageModules = [ "docker" ];
      systemPackages = [ ];
      preset.modules = [ ];
      docker.enable = true;
      docker.root = true;
    }
  '';

  prebuildScript = pkgs.writeScriptBin "prebuild-check-packages" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    ${facade.sourcePreamble { nixosRoot = "/etc/nixos"; }}
    export NIXOS_ROOT="''${NIXOS_DIR:-/etc/nixos}"
    export CONFIGS_BASE="$NIXOS_ROOT/systemConfig"
    export MONOLITH_FILE="$NIXOS_ROOT/systemConfig.nix"

    VERBOSE="''${NCC_PREFLIGHT_VERBOSE:-0}"
    SYSTEM_TYPE="${systemType}"
    HAS_DOCKER="${if hasDocker then "1" else "0"}"
    PACKAGES_EMPTY="${if packagesEmpty then "1" else "0"}"

    if [ "$VERBOSE" = "1" ]; then
      echo "  systemType: $SYSTEM_TYPE"
      echo "  hasDocker:  $HAS_DOCKER"
      echo "  emptyPkgs:  $PACKAGES_EMPTY"
    fi

    if [ "$SYSTEM_TYPE" != "homelab" ]; then
      ${ui.badges.success "Packages: ok"}
      exit 0
    fi

    seed_homelab_docker() {
      ${ui.messages.loading "Seeding packages for systemType=homelab (docker)…"}
      if ncc_write_module_config "core/base/packages" '${seedContent}'; then
        ${ui.badges.success "Packages: seeded docker for homelab"}
        ${ui.messages.info "Next rebuild will enable Docker. Opt out: clear packageModules / docker.enable and set systemType ≠ homelab."}
        return 0
      fi
      ${ui.badges.error "Packages: failed to seed docker config"}
      return 1
    }

    if [ "$PACKAGES_EMPTY" = "1" ]; then
      if [ "''${NCC_REMOTE_NONINTERACTIVE:-0}" = "1" ]; then
        seed_homelab_docker || exit 1
        exit 0
      fi
      ${ui.badges.warning "Packages: systemType=homelab but packages empty (no docker)"}
      printf "Seed docker for this homelab host now? [Y/n] "
      read -r response || response=""
      if [[ "$response" =~ ^[Nn]$ ]]; then
        ${ui.badges.warning "Packages: skipped seed — build will warn until docker is configured"}
        exit 0
      fi
      seed_homelab_docker || exit 1
      exit 0
    fi

    if [ "$HAS_DOCKER" != "1" ]; then
      ${ui.badges.warning "Packages: systemType=homelab without docker"}
      ${ui.messages.info "Add packageModules = [ \"docker\" ] or docker.enable = true (or ncc packages module add docker)"}
      # Soft: do not fail the build — explicit non-empty packages without docker is allowed.
      exit 0
    fi

    ${ui.badges.success "Packages: homelab + docker"}
    exit 0
  '';

in {
  config = lib.mkMerge [
    {
      environment.systemPackages = [ prebuildScript ];
    }
    (cliRegistry.registerCommandsFor "system-checks-packages" [
      {
        name = "check-packages";
        domain = "system";
        category = "system-checks";
        internal = true;
        description = "Check packages config before rebuild (homelab docker expectation)";
        script = "${prebuildScript}/bin/prebuild-check-packages";
        shortHelp = "check-packages - Verify packages / homelab docker";
        longHelp = ''
          When systemType=homelab and packages are empty, offers to seed docker.
          When packages are set but docker is missing, warns only.
        '';
        interactive = true;
        dependencies = [ "system-checks" ];
      }
    ])
  ];
}
