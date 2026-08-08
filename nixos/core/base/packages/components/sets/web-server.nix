# nginx web server for server / homelab roles.
# Local/dev HTTP tooling lives in the web-dev set (or user presets), not here.
{ config, lib, pkgs, ... }:
{
  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
  };

  environment.systemPackages = with pkgs; [
    nginx
  ];
}
