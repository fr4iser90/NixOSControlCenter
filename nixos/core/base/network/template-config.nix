{
  networkManager.dns = "default";
  hostName = "nixos";
  firewall.enable = true;
  firewall.trustedNetworks = [ ];
  services = { };
}
