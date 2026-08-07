{ config, lib, pkgs, getModuleApi, getModuleConfig, getModuleMetadata, ... }:
let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";

  packagesCli = import ./scripts/ncc-packages.nix { inherit pkgs getModuleMetadata; };
  packagesGui = import ./gui/default.nix { inherit pkgs packagesCli getModuleApi config; };
  guiOn = (getModuleApi "gui-engine").isEnabled getModuleConfig;
  guiOff = (getModuleApi "gui-engine").disabledHint;

  # Variant 1: bare = CLI; UI only via --gui
  packagesEntry = pkgs.writeShellScriptBin "ncc-packages-entry" ''
    set -euo pipefail
    _ui=""
    _args=()
    for _a in "$@"; do
      case "$_a" in
        --gui) _ui=gui ;;
        --tui)
          echo "packages has no TUI; use: ncc packages --gui" >&2
          exit 2
          ;;
        gui)
          echo "Use: ncc packages --gui" >&2
          exit 2
          ;;
        *) _args+=("$_a") ;;
      esac
    done
    set -- "''${_args[@]}"

    if [[ "$_ui" == "gui" ]]; then
      ${if guiOn then ''exec ${packagesGui.nccPackagesGui}/bin/ncc-packages-gui'' else guiOff}
    fi

    if [[ $# -eq 0 ]]; then
      exec ${packagesCli}/bin/ncc-packages --help
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
      (cliRegistry.registerGuiDomain "packages" {
        label = "Packages";
        description = "Package and module package sets";
        enabled = true;
        group = "core";
      })
      (cliRegistry.registerGuiPage "packages" ./ui/gui)
      (cliRegistry.registerCommandsFor "packages" [
        {
          name = "packages";
          domain = "packages";
          description = "Package management";
          category = "base";
          script = "${packagesEntry}/bin/ncc-packages-entry";
          arguments = [];
          type = "manager";
          shortHelp = "packages - Package Management";
          longHelp = ''
            ncc packages                 CLI help
            ncc packages --gui           Packages GUI

            CLI — single packages (nixpkgs):
              ncc packages add|remove|list …

            CLI — module sets:
              ncc packages module list|available|add|remove|info …
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
