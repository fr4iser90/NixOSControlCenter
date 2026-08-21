{ config, lib, pkgs, getModuleApi, ... }:

with lib;

let
  ui = getModuleApi "cli-formatter";
  common = import ../lib/common.nix { inherit lib getModuleApi; };

  # Thin provider: same shape as systemd-boot/grub, but rEFInd mutation is not implemented.
  # When selected (boot.loader.refind.enable), commands fail with a clear Next: hint.
  failStub = { name, header, usage }:
    pkgs.writeScriptBin name ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      ${common.validatePermissions}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.text.header header}
      fi
      ${ui.messages.loading "Checking rEFInd support…"}
      if [ -d /boot/EFI/refind ] || ls /boot/EFI/refind* >/dev/null 2>&1; then
        ${ui.tables.keyValue "rEFInd path" "detected under /boot/EFI"}
      else
        ${ui.tables.keyValue "rEFInd path" "not found"}
      fi
      ${ui.messages.error "rEFInd boot-entry list/rename/reset is not implemented"}
      ${ui.messages.info "Usage would be: ${usage}"}
      if [[ -z "''${NCC_CLI_NESTED:-}" ]]; then
        ${ui.messages.info "Next: use boot.loader.systemd-boot or boot.loader.grub, or contribute handlers/refind.nix"}
      fi
      exit 1
    '';

  scripts = {
    initJson = pkgs.writeScript "init-refind-entries-json" ''
      #!${pkgs.bash}/bin/bash
      # no-op: rEFInd provider does not maintain an entries JSON store
      true
    '';

    listEntries = failStub {
      name = "list-refind-entries";
      header = "rEFInd boot entries";
      usage = "ncc bootentry list";
    };

    renameEntry = failStub {
      name = "rename-refind-entry";
      header = "Rename rEFInd entry";
      usage = "ncc bootentry rename GEN TITLE";
    };

    resetEntry = failStub {
      name = "reset-refind-entry";
      header = "Reset rEFInd entry";
      usage = "ncc bootentry reset GEN";
    };
  };

  utils = { };
  types = { };

in {
  inherit scripts utils types;

  activation = {
    initializeJson = ''
      ${scripts.initJson}
    '';
    syncEntries = ''
      # rEFInd sync not implemented — activation is a no-op
      true
    '';
  };
}
