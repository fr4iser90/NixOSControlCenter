{
  enable = true;
  networkManager.dns = "default";
  hostName = "nixos";
  firewall.enable = true;
  firewall.trustedNetworks = [ ];
  services = { };
  wifi = {
    enable = true;
    preserveSystemConnections = true;
    networks = { };
  };
}
