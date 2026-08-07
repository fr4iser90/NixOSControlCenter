{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  cliRegistry = getModuleApi "cli-registry";
  ui = getModuleApi "cli-formatter";
  tuiOn = (getModuleApi "tui-engine").isEnabled getModuleConfig;
  tuiOff = (getModuleApi "tui-engine").disabledHint;
  vmTui =
    if tuiOn
    then (import ./ui/tui/default.nix { inherit config lib pkgs getModuleApi; }).tuiScript
    else null;
  domainGui = (getModuleApi "gui-engine").domainGui pkgs;
  guiOn = (getModuleApi "gui-engine").isEnabled getModuleConfig;
  guiOff = (getModuleApi "gui-engine").disabledHint;
  libVM = import ./lib { inherit lib pkgs; };
  availableDistros = attrNames libVM.distros;

  vmEntry = pkgs.writeShellScriptBin "ncc-vm-entry" ''
    set -euo pipefail
    _ui=""
    _args=()
    for _a in "$@"; do
      case "$_a" in
        --gui) _ui=gui ;;
        --tui) _ui=tui ;;
        gui|tui) echo "Use: ncc vm --$_a" >&2; exit 2 ;;
        *) _args+=("$_a") ;;
      esac
    done
    set -- "''${_args[@]}"

    case "''${1:-}" in
      "")
        case "$_ui" in
          gui) ${if guiOn then ''exec ${domainGui}/bin/ncc-domain-gui vm'' else guiOff} ;;
          tui)
            ${if tuiOn then ''exec ${vmTui}/bin/ncc-vm-tui'' else tuiOff}
            ;;
          *)
            cat <<EOF
ncc vm — VM manager (CLI)

Usage:
  ncc vm                 Help
  ncc vm --gui           Domain GUI
  ncc vm --tui           TUI (if enabled)
  ncc vm status|list|domains|start|stop|destroy|test …
EOF
            ;;
        esac
        ;;
      help|-h|--help) exec "$0" ;;
      *)
        echo "Usage: ncc vm [--gui|--tui] | ncc vm status|list|domains|start|stop|destroy|test …" >&2
        exit 1
        ;;
    esac
  '';

  # Machine-readable: name=state (one per line)
  vmDomains = pkgs.writeShellScriptBin "ncc-vm-domains" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    if ! command -v virsh >/dev/null 2>&1; then
      echo "virsh not found" >&2
      exit 1
    fi
    while IFS= read -r name; do
      [[ -z "$name" ]] && continue
      state="$(virsh domstate "$name" 2>/dev/null || echo unknown)"
      printf '%s=%s\n' "$name" "$state"
    done < <(virsh list --all --name 2>/dev/null)
  '';

  vmStart = pkgs.writeShellScriptBin "ncc-vm-start" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    name="''${1:-}"
    if [[ -z "$name" ]]; then
      echo "Usage: ncc vm start NAME" >&2
      exit 2
    fi
    virsh start "$name"
  '';

  vmStop = pkgs.writeShellScriptBin "ncc-vm-stop" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    name="''${1:-}"
    if [[ -z "$name" ]]; then
      echo "Usage: ncc vm stop NAME" >&2
      exit 2
    fi
    virsh shutdown "$name"
  '';

  vmDestroy = pkgs.writeShellScriptBin "ncc-vm-destroy" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    name="''${1:-}"
    if [[ -z "$name" ]]; then
      echo "Usage: ncc vm destroy NAME" >&2
      exit 2
    fi
    virsh destroy "$name"
  '';

  vmStatus = pkgs.writeShellScriptBin "ncc-vm-status" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    ${ui.badges.info "VM Manager Status"}
    if ! systemctl cat libvirtd.service >/dev/null 2>&1; then
      ${ui.badges.error "Libvirt is not installed"}
      exit 1
    fi
    if systemctl is-active --quiet libvirtd.service; then
      ${ui.tables.keyValue "Libvirt Daemon" "Running"}
    else
      ${ui.badges.warning "Libvirt daemon not running"}
      exit 1
    fi
    echo ""
    ${ui.badges.info "Running VMs:"}
    virsh list --state-running 2>/dev/null || true
    echo ""
    ${ui.badges.info "All VMs:"}
    virsh list --all 2>/dev/null || true
  '';

  vmList = pkgs.writeShellScriptBin "ncc-vm-list" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    ${ui.badges.info "Available VM Test Distros"}
    echo ""
    ${lib.concatMapStringsSep "\n" (distro: ''
      ${ui.tables.keyValue "${distro}" "ncc vm test run ${distro}"}
    '') availableDistros}
    echo ""
    ${ui.messages.info "ncc vm test run <distro> | ncc vm test reset <distro>"}
  '';

  # Per-distro runners (internal binaries)
  distroBins = listToAttrs (map (distro: {
    name = distro;
    value = {
      run = pkgs.writeShellScriptBin "ncc-vm-test-${distro}-run" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail
        ${ui.badges.info "Starting ${distro} test VM"}
        if command -v vm-test-${distro}-run >/dev/null 2>&1; then
          exec vm-test-${distro}-run "$@"
        fi
        ${ui.badges.error "VM test script not found"}
        exit 1
      '';
      reset = pkgs.writeShellScriptBin "ncc-vm-test-${distro}-reset" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail
        ${ui.badges.warning "Resetting ${distro} test VM"}
        if command -v vm-test-${distro}-reset >/dev/null 2>&1; then
          exec vm-test-${distro}-reset
        fi
        ${ui.badges.error "VM reset script not found"}
        exit 1
      '';
    };
  }) availableDistros);

  testRouter = pkgs.writeShellScriptBin "ncc-vm-test" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    verb="''${1:-}"
    distro="''${2:-}"
    shift || true
    shift || true
    case "$verb" in
      ""|help|-h|--help)
        cat <<EOF
ncc vm test run <distro> [flags]
ncc vm test reset <distro>

Distros: ${lib.concatStringsSep " " availableDistros}
EOF
        exit 0
        ;;
      run|reset)
        if [[ -z "$distro" ]]; then
          echo "Usage: ncc vm test $verb <distro>" >&2
          exit 1
        fi
        case "$distro" in
          ${lib.concatMapStringsSep "\n" (d: ''
          ${d})
            if [[ "$verb" == "run" ]]; then
              exec ${distroBins.${d}.run}/bin/ncc-vm-test-${d}-run "$@"
            else
              exec ${distroBins.${d}.reset}/bin/ncc-vm-test-${d}-reset "$@"
            fi
            ;;
          '') availableDistros}
          *)
            echo "Unknown distro: $distro" >&2
            exit 1
            ;;
        esac
        ;;
      *)
        echo "Unknown: ncc vm test $verb" >&2
        exit 1
        ;;
    esac
  '';

  allCommands = [
    {
      name = "vm";
      domain = "vm";
      type = "manager";
      description = "VM Manager (GUI)";
      category = "infrastructure";
      script = "${vmEntry}/bin/ncc-vm-entry";
      shortHelp = "vm - VM Manager (GUI)";
      longHelp = ''
        ncc vm
        ncc vm --gui|--tui
        ncc vm status|list|domains
        ncc vm test run|reset <distro>
      '';
    }
  ]
  ++ optionals tuiOn [
    {
      name = "tui";
      domain = "vm";
      parent = "vm";
      type = "manager";
      description = "VM TUI";
      category = "infrastructure";
      script = "${vmTui}/bin/ncc-vm-tui";
      shortHelp = "tui - VM TUI";
      longHelp = "ncc vm tui";
    }
  ]
  ++ [
    {
      name = "status";
      domain = "vm";
      parent = "vm";
      description = "Show VM manager status";
      category = "infrastructure";
      script = "${vmStatus}/bin/ncc-vm-status";
      shortHelp = "status - Show VM manager status";
      longHelp = "ncc vm status";
    }
    {
      name = "list";
      domain = "vm";
      parent = "vm";
      description = "List available test distros";
      category = "infrastructure";
      script = "${vmList}/bin/ncc-vm-list";
      shortHelp = "list - List available test distros";
      longHelp = "ncc vm list";
    }
    {
      name = "domains";
      domain = "vm";
      parent = "vm";
      description = "List libvirt domains (name=state)";
      category = "infrastructure";
      script = "${vmDomains}/bin/ncc-vm-domains";
      shortHelp = "domains - List libvirt domains";
      longHelp = "ncc vm domains";
    }
    {
      name = "start";
      domain = "vm";
      parent = "vm";
      description = "Start a libvirt domain";
      category = "infrastructure";
      script = "${vmStart}/bin/ncc-vm-start";
      shortHelp = "start NAME - Start domain";
      longHelp = "ncc vm start NAME";
    }
    {
      name = "stop";
      domain = "vm";
      parent = "vm";
      description = "ACPI shutdown a libvirt domain";
      category = "infrastructure";
      script = "${vmStop}/bin/ncc-vm-stop";
      shortHelp = "stop NAME - Shutdown domain";
      longHelp = "ncc vm stop NAME";
    }
    {
      name = "destroy";
      domain = "vm";
      parent = "vm";
      description = "Force-off a libvirt domain";
      category = "infrastructure";
      script = "${vmDestroy}/bin/ncc-vm-destroy";
      shortHelp = "destroy NAME - Force off domain";
      longHelp = "ncc vm destroy NAME";
      dangerous = true;
    }
    {
      name = "test";
      domain = "vm";
      parent = "vm";
      type = "manager";
      description = "Test VM run/reset";
      category = "infrastructure";
      script = "${testRouter}/bin/ncc-vm-test";
      shortHelp = "test - run|reset <distro>";
      longHelp = ''
        ncc vm test run <distro> [--iso|--disk|--replace|…]
        ncc vm test reset <distro>
      '';
      dangerous = false;
    }
  ];
in
{
  config = lib.mkMerge [
    (cliRegistry.registerGuiDomain "vm" {
      label = "VMs";
      description = "Libvirt domains and test VMs";
      enabled = cfg.enable or false;
    })
    (cliRegistry.registerCommandsFor "vm" allCommands)
  ];
}
