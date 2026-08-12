{ pkgs, lib, getModuleApi, getModuleMetadata }:

let
  runner = import ./runner.nix { inherit pkgs lib getModuleApi getModuleMetadata; };
in {
  inherit (runner) moduleMigrate plans;
  # Convenience alias
  migrate = runner.moduleMigrate;
}
