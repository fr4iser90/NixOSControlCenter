# Desktop-only extras on top of base/core.nix.
# LibreOffice, AppImage helpers, etc. — not CLI/dev tools (those are core or sets).

{ config, lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    libreoffice
    appimage-run
  ];
}
