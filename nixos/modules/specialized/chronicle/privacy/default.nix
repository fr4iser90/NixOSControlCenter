{ config, lib, pkgs, ... }:

{
  imports = [
    ./face-blur.nix
    ./ocr-redaction.nix
    ./encryption.nix
  ];

  options.services.chronicle.privacy = {
    enableAll = lib.mkEnableOption "all privacy features";
  };

  config = lib.mkIf config.services.chronicle.privacy.enableAll {
    services.chronicle.privacy = {
      faceBlur.enable = lib.mkDefault true;
      ocrRedaction.enable = lib.mkDefault true;
      encryption.enable = lib.mkDefault true;
    };
  };
}
