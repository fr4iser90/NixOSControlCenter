{
  description = "Homelab Server";
  systemTypes = [ "server" "homelab" ];
  features = [
    "docker-rootless"
    "database"
    "web-server"
  ];
}

