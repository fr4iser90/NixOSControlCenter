{ config, lib, pkgs, getModuleConfig, getModuleApi, getModuleMetadata, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  guiOn = (getModuleApi "gui-engine").isEnabled getModuleConfig;
  guiOff = (getModuleApi "gui-engine").disabledHint;

  hyprlandCli = import ./scripts/ncc-hyprland.nix { inherit pkgs getModuleApi; };
  hyprlandSet = import ./scripts/hyprland-set.nix {
    inherit pkgs getModuleApi getModuleMetadata getModuleConfig moduleName;
  };
  hyprlandRiceInstall = import ./scripts/hyprland-rice-install.nix {
    inherit pkgs getModuleApi getModuleMetadata getModuleConfig moduleName;
  };
  hyprlandStatus = import ./scripts/hyprland-status.nix {
    inherit pkgs getModuleApi getModuleMetadata getModuleConfig moduleName;
  };
  hyprlandGui = import ./gui/default.nix {
    inherit pkgs hyprlandCli getModuleApi config;
  };

  entry = pkgs.writeShellScriptBin "ncc-hyprland-entry" ''
    set -euo pipefail
    _ui=""
    _args=()
    for _a in "$@"; do
      case "$_a" in
        --gui) _ui=gui ;;
        --tui)
          echo "hyprland has no TUI; use: ncc hyprland --gui" >&2
          exit 2
          ;;
        gui)
          echo "Use: ncc hyprland --gui" >&2
          exit 2
          ;;
        *) _args+=("$_a") ;;
      esac
    done
    set -- "''${_args[@]}"

    if [[ "$_ui" == "gui" ]]; then
      ${if guiOn then ''exec ${hyprlandGui.nccHyprlandGui}/bin/ncc-hyprland-gui'' else guiOff}
    fi

    case "''${1:-}" in
      ""|help|-h|--help)
        exec ${hyprlandCli}/bin/ncc-hyprland --help
        ;;
      set)
        shift
        exec ${hyprlandSet}/bin/ncc-hyprland-set "$@"
        ;;
      install)
        shift
        exec ${hyprlandRiceInstall}/bin/ncc-hyprland-rice-install "$@"
        ;;
      status)
        exec ${hyprlandStatus}/bin/ncc-hyprland-status
        ;;
    esac
    exec ${hyprlandCli}/bin/ncc-hyprland "$@"
  '';

  allCommands = [
    {
      name = "hyprland";
      domain = "hyprland";
      type = "manager";
      description = "Hyprland rice catalog and wallpaper helpers";
      category = "base";
      script = "${entry}/bin/ncc-hyprland-entry";
      shortHelp = "hyprland - Hall of Fame rice store";
      longHelp = ''
        ncc hyprland --gui
        ncc hyprland rice list
        ncc hyprland rice info <id>
        ncc hyprland wallpaper list
        ncc hyprland status
        sudo ncc hyprland set rice=celestial enable=true
      '';
    }
    {
      name = "rice";
      parent = "hyprland";
      domain = "hyprland";
      description = "Browse Hall of Fame rices";
      category = "base";
      script = "${pkgs.writeShellScriptBin "ncc-hyprland-rice" ''
        exec ${hyprlandCli}/bin/ncc-hyprland rice "$@"
      ''}/bin/ncc-hyprland-rice";
      shortHelp = "rice - list or show rice presets";
      longHelp = "ncc hyprland rice list | ncc hyprland rice info <id>";
    }
    {
      name = "wallpaper";
      parent = "hyprland";
      domain = "hyprland";
      description = "List wallpapers with bundled thumbnails";
      category = "base";
      script = "${pkgs.writeShellScriptBin "ncc-hyprland-wallpaper" ''
        exec ${hyprlandCli}/bin/ncc-hyprland wallpaper "$@"
      ''}/bin/ncc-hyprland-wallpaper";
      shortHelp = "wallpaper - list catalog wallpapers";
      longHelp = "ncc hyprland wallpaper list";
    }
    {
      name = "install";
      parent = "rice";
      domain = "hyprland";
      description = "Fetch dotfiles collection and patch flake for a rice";
      category = "base";
      script = "${hyprlandRiceInstall}/bin/ncc-hyprland-rice-install";
      requiresSudo = true;
      shortHelp = "install - fetch rice collection";
      longHelp = ''
        sudo ncc hyprland rice install astroland
        sudo ncc hyprland rice install --from-set
      '';
    }
    {
      name = "status";
      parent = "hyprland";
      domain = "hyprland";
      description = "Hyprland module settings";
      category = "base";
      script = "${hyprlandStatus}/bin/ncc-hyprland-status";
      shortHelp = "status - current hyprland settings";
      longHelp = "ncc hyprland status";
    }
    {
      name = "set";
      parent = "hyprland";
      domain = "hyprland";
      description = "Write hyprland rice/wallpaper to systemConfig";
      category = "base";
      script = "${hyprlandSet}/bin/ncc-hyprland-set";
      requiresSudo = true;
      shortHelp = "set - change hyprland settings";
      longHelp = ''
        sudo ncc hyprland set enable=true rice=astroland
        sudo ncc hyprland set wallpaper.rice=rivendell
      '';
    }
  ];
in {
  config = lib.mkMerge [
    (cliRegistry.registerGuiDomain "hyprland" {
      label = "Hyprland";
      description = "Hall of Fame rices and wallpapers";
      enabled = true;
      group = "features";
    })
    (cliRegistry.registerGuiPage "hyprland" ./ui/gui)
    (cliRegistry.registerCommandsFor moduleName allCommands)
    {
      environment.systemPackages = [
        hyprlandCli
        hyprlandSet
        hyprlandRiceInstall
        hyprlandStatus
        hyprlandGui.nccHyprlandGui
        entry
      ];
    }
  ];
}
