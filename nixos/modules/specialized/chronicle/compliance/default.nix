{ config, lib, pkgs, ... }:

{
  imports = [
    ./gdpr.nix
    ./hipaa.nix
    ./retention.nix
  ];

  options.services.chronicle.compliance = {
    enableAll = lib.mkEnableOption "all compliance features";
  };

  config = lib.mkIf config.services.chronicle.compliance.enableAll {
    services.chronicle.compliance = {
      gdpr.enable = lib.mkDefault true;
      hipaa.enable = lib.mkDefault false; # Disabled by default (specific use case)
      retention.enable = lib.mkDefault true;
    };
  };
}
