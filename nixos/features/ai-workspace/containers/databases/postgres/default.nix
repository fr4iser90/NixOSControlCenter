{ config, lib, pkgs, ... }:

{
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      ai-postgres = {
        image = "postgres:15";
        ports = [ "5432:5432" ];
        volumes = [
          "postgres-data:/var/lib/postgresql/data"
          "${../../../schemas/postgres/init.sql}:/docker-entrypoint-initdb.d/init.sql"  # Schema hinzugefügt
        ];
        environment = {
          POSTGRES_DB = "ai_development";
          POSTGRES_USER = "ai_user";
          POSTGRES_PASSWORD = "ai_password"; # In Produktion durch sicheres Passwort ersetzen!
        };
        extraOptions = [
          "--network=host"
        ];
        autoStart = true;
      };
    };
  };
}