{ config, lib, pkgs, getCurrentModuleMetadata, ... }:
let
  # GENERISCH: NCC API über Metadata finden
  metadata = getCurrentModuleMetadata ./.;
  nccApi = lib.attrByPath (lib.splitString "." "${metadata.configPath}.api") {} config;
  formatter = nccApi.formatter or {};
  registry = nccApi.registry or {};
in {
  # Example NCC command
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "ncc-hello" ''
      #!${pkgs.bash}/bin/bash
      echo "Hello from NixOS Control Center!"
    '')
  ];
}
