{
  description = "Homelab Server (Docker + PostgreSQL + nginx)";
  systemTypes = [ "server" "homelab" ];
  scope = "system";
  modules = [
    "docker"
    "database"
    "web-server"
  ];
}
