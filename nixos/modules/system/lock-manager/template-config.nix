{
  enable = false;
  scanInterval = "";
  snapshotDir = "/var/lib/nixos-control-center/snapshots";
  
  encryption = {
    enable = true;
    method = "both";
    sops = {
      keysFile = "";
      ageKeyFile = "";
    };
    fido2 = {
      device = "";
      pin = "";
    };
  };
  
  github = {
    enable = false;
    repository = "";
    branch = "main";
    tokenFile = "";
  };
  
  scanners = {
    desktop = true;
    steam = true;
    credentials = {
      enable = true;
      includePrivateKeys = false;
      keyTypes = [ "ssh" "gpg" ];
      requireFIDO2 = true;
    };
    packages = true;
    browser = true;
    ide = true;
  };
  
  audit = {
    enable = false;
    logFile = "/var/log/ncc-discovery-audit.log";
    logLevel = "info";
  };
  
  retention = {
    maxSnapshots = 0;
    maxAge = "";
    compressOld = false;
  };
  
  compliance = {
    enable = false;
    requireEncryption = true;
    requireGitHubBackup = false;
    dataClassification = "core";
  };
}
