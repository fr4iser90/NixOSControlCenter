{
  description = "Homelab Server (Docker + PostgreSQL + nginx)";
  systemTypes = [ "server" ];
  scope = "system";
  modules = [
    "docker"
    "database"
    "web-server"
  ];
}
