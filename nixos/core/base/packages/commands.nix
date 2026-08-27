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
    longHelp = "See: ncc packages ${name} --help";
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
      longHelp = ''
        Add packages to systemConfig (current user by default).

        Examples:
          ncc packages add firefox
          ncc packages add nginx --system
          ncc packages add code --user alice
      '';
    }
    {
      name = "remove";
      parent = "packages";
      domain = "packages";
      description = "Remove packages from systemConfig";
      category = "base";
      script = (packagesChild "remove").script;
      shortHelp = "remove - packages remove";
      longHelp = ''
        Remove packages from systemConfig (same defaults as add).

        Examples:
          ncc packages remove firefox
          ncc packages remove nginx --system
      '';
    }
    {
      name = "list";
      parent = "packages";
      domain = "packages";
      description = "List configured packages";
      category = "base";
      script = (packagesChild "list").script;
      shortHelp = "list - packages list";
      longHelp = ''
        List configured user and/or system packages.

        Examples:
          ncc packages list
          ncc packages list --system
      '';
    }
    {
      name = "search";
      parent = "packages";
      domain = "packages";
      description = "Search store intents";
      category = "base";
      script = (packagesChild "search").script;
      shortHelp = "search - packages search";
      longHelp = ''
        Search the package store by intent / keyword.

        Examples:
          ncc packages search editor
          ncc packages search "video player"
      '';
    }
    {
      name = "resolve";
      parent = "packages";
      domain = "packages";
      description = "Resolve store intents";
      category = "base";
      script = (packagesChild "resolve").script;
      shortHelp = "resolve - packages resolve";
      longHelp = ''
        Resolve a store intent to concrete package names.

        Examples:
          ncc packages resolve editor
      '';
    }
    {
      name = "try";
      parent = "packages";
      domain = "packages";
      description = "Temporary nix-shell try";
      category = "base";
      script = (packagesChild "try").script;
      shortHelp = "try - packages try";
      longHelp = ''
        Try a package in a temporary shell (does not write systemConfig).

        Examples:
          ncc packages try htop
      '';
    }
    {
      name = "categories";
      parent = "packages";
      domain = "packages";
      description = "List store categories";
      category = "base";
      script = (packagesChild "categories").script;
      shortHelp = "categories - packages categories";
      longHelp = ''
        List package-store categories.

        Examples:
          ncc packages categories
      '';
    }
    {
      name = "module";
      parent = "packages";
      domain = "packages";
      description = "Module package sets";
      category = "base";
      script = (packagesChild "module").script;
      shortHelp = "module - packages module";
      longHelp = ''
        Manage feature/module package sets.

        Examples:
          ncc packages module list
          ncc packages module available
          ncc packages module add gaming
          ncc packages module info docker
      '';
    }
  ];
in
{
  # Core domain: always in catalog + CLI so GUI can manage packages even if
  # a host had previously toggled something off (config manager, not viewer).
  config = lib.mkMerge [
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
            Manage packages and module package sets in systemConfig.

            Examples:
              ncc packages                 CLI help
              ncc packages --gui           Packages GUI
              ncc packages add firefox
              ncc packages list --system
              ncc packages search editor
              ncc packages module add gaming
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
  ];
}
