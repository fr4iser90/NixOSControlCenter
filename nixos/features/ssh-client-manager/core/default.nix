{ config, lib, pkgs, systemConfig, ... }:

let
  inherit (import ../lib/tools.nix { inherit lib; }) setupUserCreds;
in {
  imports = [
    ./config.nix
    ./manager.nix
    ./connect.nix
  ];

  config = {
    system.activationScripts.sshManagerSetup = let
      configuredUsers = lib.attrNames systemConfig.users;
    in ''
      # Erstelle .creds für konfigurierte Benutzer
      ${lib.concatMapStrings setupUserCreds configuredUsers}
    '';
  };
}
