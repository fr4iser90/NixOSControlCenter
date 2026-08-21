{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  ui = getModuleApi "cli-formatter";
  cliRegistry = getModuleApi "cli-registry";

  providers = {
    grub = import ./handlers/grub.nix { inherit config lib pkgs getModuleApi; };
    "systemd-boot" = import ./handlers/systemd-boot.nix { inherit config lib pkgs getModuleApi; };
    refind = import ./handlers/refind.nix { inherit config lib pkgs getModuleApi; };
  };

  useGrub = config.boot.loader.grub.enable && !config.boot.loader.systemd-boot.enable;
  refindOn = attrByPath [ "boot" "loader" "refind" "enable" ] false config;
  useRefind =
    refindOn
    && !config.boot.loader.systemd-boot.enable
    && !config.boot.loader.grub.enable;

  selectedProvider =
    if config.boot.loader.systemd-boot.enable then providers."systemd-boot"
    else if config.boot.loader.grub.enable then providers.grub
    else if useRefind then providers.refind
    else providers."systemd-boot";

  listBin = "${selectedProvider.scripts.listEntries}/bin/${
    if useGrub then "list-grub-entries"
    else if useRefind then "list-refind-entries"
    else "list-boot-entries"
  }";
  renameBin = "${selectedProvider.scripts.renameEntry}/bin/${
    if useGrub then "rename-grub-entry"
    else if useRefind then "rename-refind-entry"
    else "rename-boot-entry"
  }";
  resetBin = "${selectedProvider.scripts.resetEntry}/bin/${
    if useGrub then "reset-grub-entry"
    else if useRefind then "reset-refind-entry"
    else "reset-boot-entry"
  }";

  # Thin ncc router: handlers already own §3 skeleton; nested skip duplicate chrome
  bootentryEntry = pkgs.writeShellScriptBin "ncc-bootentry" ''
    set -euo pipefail
    case "''${1:-}" in
      ""|help|-h|--help)
        if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
          ${ui.text.header "Boot entries"}
        fi
        cat <<EOF
ncc bootentry — Boot entry manager (CLI)

Usage:
  ncc bootentry list
  ncc bootentry rename GEN TITLE
  ncc bootentry reset GEN
EOF
        if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
          ${ui.messages.info "Next: ncc bootentry list"}
        fi
        ;;
      list)
        shift || true
        exec ${listBin} "$@"
        ;;
      rename)
        shift || true
        exec ${renameBin} "$@"
        ;;
      reset)
        shift || true
        exec ${resetBin} "$@"
        ;;
      *)
        ${ui.messages.error ''Unknown: ncc bootentry ''${1:-}''}
        ${ui.messages.info "Next: ncc bootentry --help"}
        exit 1
        ;;
    esac
  '';

  listCmd = pkgs.writeShellScriptBin "ncc-bootentry-list" ''
    set -euo pipefail
    exec ${listBin} "$@"
  '';
  renameCmd = pkgs.writeShellScriptBin "ncc-bootentry-rename" ''
    set -euo pipefail
    exec ${renameBin} "$@"
  '';
  resetCmd = pkgs.writeShellScriptBin "ncc-bootentry-reset" ''
    set -euo pipefail
    exec ${resetBin} "$@"
  '';

  allCommands = [
    {
      name = "bootentry";
      domain = "bootentry";
      type = "manager";
      description = "Boot entry list / rename / reset";
      category = "infrastructure";
      script = "${bootentryEntry}/bin/ncc-bootentry";
      shortHelp = "bootentry - Manage bootloader generation titles";
      longHelp = ''
        ncc bootentry list
        ncc bootentry rename GEN TITLE
        ncc bootentry reset GEN
      '';
    }
    {
      name = "list";
      parent = "bootentry";
      domain = "bootentry";
      description = "List bootloader generation entries";
      category = "infrastructure";
      script = "${listCmd}/bin/ncc-bootentry-list";
      shortHelp = "list - Show generation entry confs";
      longHelp = "ncc bootentry list";
    }
    {
      name = "rename";
      parent = "bootentry";
      domain = "bootentry";
      description = "Rename a boot generation title";
      category = "infrastructure";
      script = "${renameCmd}/bin/ncc-bootentry-rename";
      shortHelp = "rename GEN TITLE - Set generation title";
      longHelp = "ncc bootentry rename GEN TITLE";
    }
    {
      name = "reset";
      parent = "bootentry";
      domain = "bootentry";
      description = "Reset a boot generation title";
      category = "infrastructure";
      script = "${resetCmd}/bin/ncc-bootentry-reset";
      shortHelp = "reset GEN - Reset generation title";
      longHelp = "ncc bootentry reset GEN";
    }
  ];
in
{
  config = mkMerge [
    (cliRegistry.registerGuiDomain "bootentry" {
      label = "Boot entries";
      description = "Rename and reset bootloader generation titles";
      enabled = cfg.enable or false;
      group = "features";
    })
    (mkIf (cfg.enable or false) (
      cliRegistry.registerCommandsFor "bootentry-manager" allCommands
    ))
  ];
}
