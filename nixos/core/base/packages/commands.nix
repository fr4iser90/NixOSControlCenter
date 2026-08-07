{ config, lib, pkgs, getModuleApi, getModuleConfig, getModuleMetadata, ... }:
let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";

  packagesCli = import ./scripts/ncc-packages.nix { inherit pkgs getModuleMetadata; };
  packagesGui = import ./gui/default.nix { inherit pkgs packagesCli getModuleApi; };

  # Bare `ncc packages` → GUI; any subcommand/flags → CLI
  packagesEntry = pkgs.writeShellScriptBin "ncc-packages-entry" ''
    set -euo pipefail
    if [[ $# -eq 0 ]] || [[ "''${1:-}" == "gui" ]]; then
      exec ${packagesGui.nccPackagesGui}/bin/ncc-packages-gui
    fi
    case "''${1:-}" in
      -h|--help|help)
        exec ${packagesCli}/bin/ncc-packages --help
        ;;
    esac
    exec ${packagesCli}/bin/ncc-packages "$@"
  '';
in
{
  config = lib.mkIf (cfg.enable or true)
    (lib.mkMerge [
      (cliRegistry.registerCommandsFor "packages" [
        {
          name = "packages";
          domain = "packages";
          description = "Package management (GUI + CLI)";
          category = "base";
          script = "${packagesEntry}/bin/ncc-packages-entry";
          arguments = [];
          type = "manager";
          shortHelp = "packages - Package Management (GUI)";
          longHelp = ''
            Package management GUI (default) and CLI.

            GUI (default):
              ncc packages
              ncc packages gui

            CLI — single packages (nixpkgs):
              ncc packages add <package> [--user <name>] [--system]
              ncc packages remove <package> [--user <name>] [--system]
              ncc packages list [--system]

            CLI — module sets and presets (packageModules):
              ncc packages module list
              ncc packages module available
              ncc packages module add <name>...
              ncc packages module remove <name>...
              ncc packages module info <name>

            Catalog SSOT: core/base/packages/lib/catalog.nix (+ metadata.nix).
            Mutations via config-facade (monolith or split layout).

            Layout:
              ncc system config-layout detect
              ncc system config-layout convert --to monolith|split
          '';
        }
      ])
      {
        environment.systemPackages = [
          packagesCli
          packagesGui.nccPackagesGui
          packagesEntry
        ];
      }
    ]);
}
