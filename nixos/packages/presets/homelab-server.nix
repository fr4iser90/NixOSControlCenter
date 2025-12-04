{
  description = "Homelab Server";
  systemTypes = [ "server" ];
  features = [
    "docker-rootless"
    "database"
    "web-server"
  ];
}

