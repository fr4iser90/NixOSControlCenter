{ config, lib, pkgs, getModuleApi, getModuleConfig, getModuleMetadata, ... }:

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  domainGui = (getModuleApi "gui-engine").domainGui pkgs config;
  guiOn = (getModuleApi "gui-engine").isEnabled getModuleConfig;
  guiOff = (getModuleApi "gui-engine").disabledHint;

  installer = import ./scripts { inherit pkgs; };

  resolveRepoSnippet = ''
    _ncc_install_repo() {
      if [[ -n "${cfg.repoPath or ""}" && -d "${cfg.repoPath or ""}/nixos/core" ]]; then
        printf '%s\n' "${cfg.repoPath or ""}"
        return 0
      fi
      if [[ -n "''${NCC_INSTALL_REPO:-}" && -d "''${NCC_INSTALL_REPO}/nixos/core" ]]; then
        printf '%s\n' "$NCC_INSTALL_REPO"
        return 0
      fi
      local d
      d="$(pwd)"
      while [[ "$d" != "/" ]]; do
        if [[ -d "$d/nixos/core/management" ]]; then
          printf '%s\n' "$d"
          return 0
        fi
        d="$(dirname "$d")"
      done
      return 1
    }
  '';

  entry = pkgs.writeShellScriptBin "ncc-install-entry" ''
    set -euo pipefail
    ${resolveRepoSnippet}
    _ui=""
    _args=()
    for _a in "$@"; do
      case "$_a" in
        --gui) _ui=gui ;;
        --tui) echo "install has no Go TUI; use --gui or fzf via nix-shell" >&2; exit 2 ;;
        gui|tui) echo "Use: ncc install --$_a" >&2; exit 2 ;;
        *) _args+=("$_a") ;;
      esac
    done
    set -- "''${_args[@]}"

    if [[ "$_ui" == "gui" && $# -eq 0 ]]; then
      ${if guiOn then ''exec ${domainGui}/bin/ncc-domain-gui install'' else guiOff}
    fi

    case "''${1:-}" in
      ""|help|-h|--help)
        cat <<EOF
ncc install — Install / migrate wizard

Usage:
  ncc install                 Help
  ncc install --gui           Install domain GUI (preflight + actions)
  ncc install wizard          PySide6 wizard (separate window)
  ncc install dry-run         Dry-run install flow
  ncc install shell           Print nix-shell invocation
EOF
        ;;
      wizard)
        shift || true
        exec ${installer.ncc-install-wizard}/bin/ncc-install-wizard "$@"
        ;;
      dry-run)
        shift || true
        exec ${installer.ncc-install-dry}/bin/ncc-install-dry "$@"
        ;;
      shell)
        repo="$(_ncc_install_repo)" || {
          echo "Could not find NixOSControlCenter checkout (set repoPath or NCC_INSTALL_REPO)" >&2
          exit 1
        }
        echo "NCC_INSTALL_SHELL_ONLY=1 nix-shell \"$repo/shell.nix\""
        ;;
      *)
        echo "Unknown: ncc install $1" >&2
        exit 1
        ;;
    esac
  '';
in
{
  config = lib.mkMerge [
    (cliRegistry.registerGuiDomain "install" {
      label = "Install";
      description = "Install / migrate wizard";
      enabled = true;
      group = "core";
    })
    (cliRegistry.registerGuiPage "install" ./ui/gui)
    (cliRegistry.registerCommandsFor "install" [
      {
        name = "install";
        domain = "install";
        type = "manager";
        description = "Install / migrate wizard";
        category = "management";
        script = "${entry}/bin/ncc-install-entry";
        shortHelp = "install - Install / migrate wizard";
        longHelp = ''
          ncc install                 Help
          ncc install --gui
          ncc install wizard|dry-run|shell
        '';
      }
    ])
  ];
}
