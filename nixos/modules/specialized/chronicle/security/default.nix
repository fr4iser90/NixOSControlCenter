{ config, lib, pkgs, ... }:

{
  imports = [
    ./rbac.nix
    ./sandbox.nix
    ./mac-profiles.nix
    ./validation.nix
  ];

  options.services.chronicle.security = {
    enableAll = lib.mkEnableOption "all security features";
  };

  config = lib.mkIf config.services.chronicle.security.enableAll {
    services.chronicle.security = {
      rbac.enable = lib.mkDefault true;
      sandbox.enable = lib.mkDefault true;
      macProfiles.enable = lib.mkDefault true;
      validation.enable = lib.mkDefault true;
    };
  };
}
