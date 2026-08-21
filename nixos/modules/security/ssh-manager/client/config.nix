{ lib, ... }:

# Legacy: seeded systemConfig/modules/security/ssh-manager/client-connections.nix
# with kitty/nano defaults. Nothing reads that file — SSH client hosts live in ~/.creds.
# This activation only deletes the hybrid leftover so monolith stays clean.
let
  legacyDir = "/etc/nixos/systemConfig/modules/security/ssh-manager";
  legacyFile = "${legacyDir}/client-connections.nix";
in {
  config.system.activationScripts.ssh-manager-client-legacy-cleanup = {
    deps = [ "etc" ];
    text = ''
      if [ -e "${legacyFile}" ] || [ -d "${legacyDir}" ]; then
        rm -rf "${legacyDir}" 2>/dev/null || true
        rmdir /etc/nixos/systemConfig/modules/security 2>/dev/null || true
        rmdir /etc/nixos/systemConfig/modules 2>/dev/null || true
        if [ -d /etc/nixos/systemConfig ] && [ ! -d /etc/nixos/systemConfig/custom ]; then
          if [ -z "$(find /etc/nixos/systemConfig -mindepth 1 2>/dev/null | head -1)" ]; then
            rmdir /etc/nixos/systemConfig 2>/dev/null || true
          fi
        fi
        echo "ncc: removed legacy SSH client store under systemConfig/ (hosts: ~/.creds)"
      fi
    '';
  };
}
