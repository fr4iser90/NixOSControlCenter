{
  enable = false;
  mode = "automatic";
  outputDir = "$HOME/.local/share/chronicle";
  format = "html";
  
  privacy = {
    redactPasswords = true;
    whitelist = [];
    blacklist = [ "password-manager" "keepassxc" "1password" "bitwarden" ];
    enableOCR = false;
    sensitivePatterns = [
      "password.*[:=].*"
      "secret.*[:=].*"
      "token.*[:=].*"
      "api[_-]?key.*[:=].*"
      "private[_-]?key.*[:=].*"
    ];
  };
  
  recording = {
    screenshotQuality = 85;
    maxSteps = 1000;
    autoTrigger = true;
    manualTrigger = true;
    enableVideo = false;
    enableAudio = false;
    enableKeyboard = false;
    videoQuality = "medium";
    audioBitrate = 64;
  };
  
  performance = {
    enableOptimization = true;
    enableThumbnails = true;
    thumbnailSize = 300;
    backgroundExport = true;
    maxSessions = 50;
    maxSessionAgeDays = 30;
    enableResourceMonitoring = true;
  };
  
  gui = {
    enableTray = true;
    enableGtk = true;
  };
  
  theme = {
    enableDarkMode = true;
    autoDetectTheme = true;
    defaultTheme = "auto";
    customTheme = null;
    enableCustomThemes = true;
  };
  
  service = {
    enableDaemon = false;
    autoStart = false;
  };
  
  smartDetection = {
    enable = true;
    windowTitleChange = {
      enable = true;
      delaySeconds = 2;
    };
    clickClustering = {
      enable = true;
      radiusPixels = 50;
      timeoutSeconds = 5;
    };
    idleDetection = {
      enable = true;
      thresholdSeconds = 10;
    };
    activityTriggers = {
      enable = false;
      minGapSeconds = 30;
    };
  };
  
  api = {
    enable = false;
    host = "127.0.0.1";
    port = 8000;
    tokenExpireMinutes = 60;
    corsOrigins = [ "*" ];
    enableAuth = true;
    enableWebhooks = true;
    autoStart = false;
  };
  
  integrations = {
    github = {
      enable = false;
    };
    gitlab = {
      enable = false;
    };
    jira = {
      enable = false;
    };
  };
  
  cloud = {
    s3 = {
      enable = false;
    };
    nextcloud = {
      enable = false;
    };
    dropbox = {
      enable = false;
    };
  };
  
  email = {
    enable = false;
  };
  
  analysis = {
    performanceMetrics = {
      enable = false;
    };
    systemLogs = {
      enable = false;
    };
    fileChanges = {
      enable = false;
    };
  };
  
  ai = {
    llm = {
      enable = false;
    };
    anomalyDetection = {
      enable = false;
    };
    patternRecognition = {
      enable = false;
    };
  };
  
  collaboration = {
    realtime = {
      enable = false;
    };
  };
  
  visualization = {
    heatmaps = {
      enable = false;
    };
  };
  
  plugins = {
    enable = false;
  };
}
