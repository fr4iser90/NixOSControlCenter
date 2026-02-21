{
  enable = false;
  
  webService = {
    enable = false;
    port = 8080;
    host = "127.0.0.1";
    autoStart = false;
  };
  
  snapshot = {
    enable = true;
  };
  
  mapping = {
    databasePath = ./web-service/api/static/data/mapping-database.json;
  };
  
  isoBuilder = {
    enable = false;
    outputDir = "/var/lib/nixify/isos";
  };
}
