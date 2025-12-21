{
  description = "Homelab Server";
  systemTypes = [ "server" ];
  modules = [
    "docker"
    "database"
    "web-server"
  ];
}

