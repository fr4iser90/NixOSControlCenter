{ config, lib, pkgs, getModuleApi, getModuleConfig, getModuleMetadata, ... }:
let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";

  packagesCli = import ./scripts/ncc-packages.nix { inherit pkgs getModuleMetadata getModuleApi; };
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

  # Literal name=/parent= so GUI button tests can discover registrations.
  # Entry-only verbs fail with: Unknown command 'packages <verb>'.
  packagesChild = name: {
    inherit name;
    parent = "packages";
    domain = "packages";
    description = "packages ${name}";
    category = "base";
    script = "${pkgs.writeShellScriptBin "ncc-packages-${name}" ''
      exec ${packagesCli}/bin/ncc-packages ${name} "$@"
    ''}/bin/ncc-packages-${name}";
    shortHelp = "${name} - packages ${name}";
    longHelp = "ncc packages ${name} …";
  };

  # Duplicate name= strings below are intentional (static discovery for tests).
  packagesChildren = [
    {
      name = "add";
      parent = "packages";
      domain = "packages";
      description = "Add packages to systemConfig";
      category = "base";
      script = (packagesChild "add").script;
      shortHelp = "add - packages add";
      longHelp = "ncc packages add …";
    }
    {
      name = "remove";
      parent = "packages";
      domain = "packages";
      description = "Remove packages from systemConfig";
      category = "base";
      script = (packagesChild "remove").script;
      shortHelp = "remove - packages remove";
      longHelp = "ncc packages remove …";
    }
    {
      name = "list";
      parent = "packages";
      domain = "packages";
      description = "List configured packages";
      category = "base";
      script = (packagesChild "list").script;
      shortHelp = "list - packages list";
      longHelp = "ncc packages list …";
    }
    {
      name = "search";
      parent = "packages";
      domain = "packages";
      description = "Search store intents";
      category = "base";
      script = (packagesChild "search").script;
      shortHelp = "search - packages search";
      longHelp = "ncc packages search …";
    }
    {
      name = "resolve";
      parent = "packages";
      domain = "packages";
      description = "Resolve store intents";
      category = "base";
      script = (packagesChild "resolve").script;
      shortHelp = "resolve - packages resolve";
      longHelp = "ncc packages resolve …";
    }
    {
      name = "try";
      parent = "packages";
      domain = "packages";
      description = "Temporary nix-shell try";
      category = "base";
      script = (packagesChild "try").script;
      shortHelp = "try - packages try";
      longHelp = "ncc packages try …";
    }
    {
      name = "categories";
      parent = "packages";
      domain = "packages";
      description = "List store categories";
      category = "base";
      script = (packagesChild "categories").script;
      shortHelp = "categories - packages categories";
      longHelp = "ncc packages categories …";
    }
    {
      name = "module";
      parent = "packages";
      domain = "packages";
      description = "Module package sets";
      category = "base";
      script = (packagesChild "module").script;
      shortHelp = "module - packages module";
      longHelp = "ncc packages module …";
    }
  ];
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
      (cliRegistry.registerCommandsFor "packages" (
        [
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

              CLI — Store (intent search / try):
                ncc packages search|resolve|try|categories …

              CLI — module sets:
                ncc packages module list|available|add|remove|info …
            '';
          }
        ]
        ++ packagesChildren
      ))
      {
        environment.systemPackages = [
          packagesCli
          packagesGui.nccPackagesGui
          packagesEntry
        ];
      }
    ]);
}
