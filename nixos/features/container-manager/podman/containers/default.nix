{ config, lib, pkgs, ... }:

{
  imports = [
    ./adblocker/pihole
  ];

  services.pihole = {
    enable = true;
    webPassword = "securepassword";
    subdomain = "pihole";
    domain = "local";
    dns = [ "1.1.1.1" "1.0.0.1" ];
  };
}
