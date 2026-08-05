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

  isoBuilder = {
    enable = false;
    outputDir = "/var/lib/nixify/isos";
  };
}
