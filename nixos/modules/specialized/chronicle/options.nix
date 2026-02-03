{ config, lib, pkgs, ... }:

let
  moduleVersion = "0.5.0";
in
{
  options.systemConfig.modules.specialized.chronicle = {
    # Version metadata (REQUIRED)
    _version = lib.mkOption {
      type = lib.types.str;
      default = moduleVersion;
      internal = true;
      description = "Module version";
    };

    # Enable option for optional modules
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Chronicle module";
    };

    # Recording mode
    mode = lib.mkOption {
      type = lib.types.enum [ "automatic" "manual" ];
      default = "automatic";
      description = ''
        Recording mode:
        - automatic: Auto-detect events (X11 only)
        - manual: Manual capture mode (works on Wayland)
      '';
    };

    # Output directory
    outputDir = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.local/share/chronicle";
      description = "Directory where recordings are stored";
    };

    # Export format
    format = lib.mkOption {
      type = lib.types.enum [ "html" "markdown" "json" "pdf" "all" ];
      default = "html";
      description = "Default export format for recordings";
    };

    # Privacy settings
    privacy = lib.mkOption {
      type = lib.types.submodule {
        options = {
          redactPasswords = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Automatically redact sensitive text patterns";
          };

          whitelist = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = ''
              Application whitelist. If empty, record all windows.
              If specified, only record windows from these applications.
            '';
          };

          blacklist = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "password-manager" "keepassxc" "1password" "bitwarden" ];
            description = "Applications to never record";
          };

          enableOCR = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable OCR for text detection and redaction";
          };

          sensitivePatterns = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "password.*[:=].*"
              "secret.*[:=].*"
              "token.*[:=].*"
              "api[_-]?key.*[:=].*"
              "private[_-]?key.*[:=].*"
            ];
            description = "Regex patterns for sensitive text to redact";
          };
        };
      };
      default = {};
      description = "Privacy settings for recording";
    };

    # Recording settings
    recording = lib.mkOption {
      type = lib.types.submodule {
        options = {
          screenshotQuality = lib.mkOption {
            type = lib.types.ints.between 1 100;
            default = 85;
            description = "JPEG quality for screenshots (1-100)";
          };

          maxSteps = lib.mkOption {
            type = lib.types.int;
            default = 1000;
            description = "Maximum number of steps per recording session";
          };

          autoTrigger = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Automatically capture steps based on window changes";
          };

          manualTrigger = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Allow manual step capture";
          };

          # Phase 3: Enhanced UX features
          enableVideo = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable video recording alongside screenshots";
          };

          enableAudio = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable audio commentary recording";
          };

          enableKeyboard = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable keyboard input recording (privacy-protected)";
          };

          videoQuality = lib.mkOption {
            type = lib.types.enum [ "low" "medium" "high" "ultra" ];
            default = "medium";
            description = ''
              Video recording quality:
              - low: 15 FPS, higher compression
              - medium: 30 FPS, balanced
              - high: 60 FPS, lower compression
              - ultra: 60 FPS, minimal compression
            '';
          };

          audioBitrate = lib.mkOption {
            type = lib.types.int;
            default = 64;
            description = "Audio bitrate in kbps (32-320)";
          };
        };
      };
      default = {};
      description = "Recording settings";
    };

    # Performance settings
    performance = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enableOptimization = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable screenshot compression and optimization";
          };

          enableThumbnails = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Generate thumbnails for lazy loading in reports";
          };

          thumbnailSize = lib.mkOption {
            type = lib.types.int;
            default = 300;
            description = "Thumbnail size in pixels";
          };

          backgroundExport = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Export reports in background to avoid blocking";
          };

          maxSessions = lib.mkOption {
            type = lib.types.int;
            default = 50;
            description = "Maximum number of sessions to keep (older ones will be deleted)";
          };

          maxSessionAgeDays = lib.mkOption {
            type = lib.types.int;
            default = 30;
            description = "Maximum age of sessions in days (older ones will be deleted)";
          };

          enableResourceMonitoring = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Monitor CPU and memory usage during recording";
          };
        };
      };
      default = {};
      description = "Performance settings";
    };

    # GUI settings
    gui = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enableTray = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable system tray icon";
          };

          enableGtk = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable GTK4 GUI application";
          };
        };
      };
      default = {};
      description = "GUI settings";
    };

    # Theme settings (Phase 3-4)
    theme = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enableDarkMode = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable dark mode support in HTML reports";
          };

          autoDetectTheme = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Auto-detect system theme preference";
          };

          defaultTheme = lib.mkOption {
            type = lib.types.enum [ "light" "dark" "auto" ];
            default = "auto";
            description = "Default theme for reports";
          };
          
          # Custom theme system (v1.2.0)
          customTheme = lib.mkOption {
            type = lib.types.nullOr (lib.types.enum [ 
              "default" "professional" "minimalist" "vibrant" "high-contrast" 
            ]);
            default = null;
            description = ''
              Custom theme to use for reports. Available builtin themes:
              - default: Clean, professional default theme
              - professional: Corporate-friendly theme
              - minimalist: Clean, minimal design
              - vibrant: Colorful, modern theme
              - high-contrast: Accessibility-focused theme
              Set to null to use system default.
            '';
          };
          
          enableCustomThemes = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable custom theme system";
          };
        };
      };
      default = {};
      description = "Theme settings";
    };

    # Service settings
    service = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enableDaemon = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable chronicle as a systemd user service";
          };

          autoStart = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Auto-start recording on login";
          };
        };
      };
      default = {};
      description = "Service settings";
    };

    # Smart Detection settings (v1.2.0)
    smartDetection = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable smart step detection for automatic step capture";
          };

          windowTitleChange = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Automatically create a step when window title changes";
                };

                delaySeconds = lib.mkOption {
                  type = lib.types.int;
                  default = 2;
                  description = "Minimum delay between window change steps (seconds)";
                };
              };
            };
            default = {};
            description = "Window title change detection";
          };

          clickClustering = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Detect clusters of clicks in the same area";
                };

                radiusPixels = lib.mkOption {
                  type = lib.types.int;
                  default = 50;
                  description = "Radius in pixels to consider clicks as part of a cluster";
                };

                timeoutSeconds = lib.mkOption {
                  type = lib.types.int;
                  default = 5;
                  description = "Maximum time between clicks in a cluster (seconds)";
                };
              };
            };
            default = {};
            description = "Click clustering detection";
          };

          idleDetection = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Detect when user becomes idle or active again";
                };

                thresholdSeconds = lib.mkOption {
                  type = lib.types.int;
                  default = 10;
                  description = "Idle time threshold to trigger idle state (seconds)";
                };
              };
            };
            default = {};
            description = "Idle detection";
          };

          activityTriggers = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Create steps based on sustained user activity";
                };

                minGapSeconds = lib.mkOption {
                  type = lib.types.int;
                  default = 30;
                  description = "Minimum gap between activity-triggered steps (seconds)";
                };
              };
            };
            default = {};
            description = "Activity trigger detection";
          };
        };
      };
      default = {};
      description = "Smart detection settings";
    };

    # API settings (v2.0.0 - Phase 5)
    api = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable REST API server for remote control and integration";
          };

          host = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1";
            description = "API server bind address (use 0.0.0.0 for external access)";
          };

          port = lib.mkOption {
            type = lib.types.port;
            default = 8000;
            description = "API server port";
          };

          tokenExpireMinutes = lib.mkOption {
            type = lib.types.int;
            default = 60;
            description = "JWT token expiration time in minutes";
          };

          corsOrigins = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "*" ];
            description = ''
              CORS allowed origins. Use ["*"] for all origins (development only),
              or specify exact origins like ["https://example.com"] for production.
            '';
          };

          enableAuth = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable authentication (JWT tokens and API keys)";
          };

          enableWebhooks = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Enable webhook support for event notifications";
          };

          autoStart = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Auto-start API server as systemd service";
          };
        };
      };
      default = {};
      description = "API settings";
    };

    # Bug Tracker Integrations (v2.0.0 - Phase 5)
    integrations = lib.mkOption {
      type = lib.types.submodule {
        options = {
          github = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Enable GitHub Issues integration";
                };
              };
            };
            default = {};
            description = "GitHub integration";
          };

          gitlab = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Enable GitLab Issues integration";
                };
              };
            };
            default = {};
            description = "GitLab integration";
          };

          jira = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Enable JIRA integration";
                };
              };
            };
            default = {};
            description = "JIRA integration";
          };
        };
      };
      default = {};
      description = "Bug tracker integrations";
    };

    # Cloud Upload (v2.0.0 - Phase 5)
    cloud = lib.mkOption {
      type = lib.types.submodule {
        options = {
          s3 = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Enable S3-compatible cloud upload (AWS S3, MinIO, DigitalOcean Spaces, Backblaze B2)";
                };
              };
            };
            default = {};
            description = "S3 cloud storage";
          };

          nextcloud = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Enable Nextcloud/WebDAV upload";
                };
              };
            };
            default = {};
            description = "Nextcloud storage";
          };

          dropbox = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Enable Dropbox upload";
                };
              };
            };
            default = {};
            description = "Dropbox storage";
          };
        };
      };
      default = {};
      description = "Cloud upload settings";
    };

    # Email Integration (v2.0.0 - Phase 5)
    email = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable email integration (SMTP)";
          };
        };
      };
      default = {};
      description = "Email integration settings";
    };

    # Analysis & Insights (v2.0.0 - Phase 5)
    analysis = lib.mkOption {
      type = lib.types.submodule {
        options = {
          performanceMetrics = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Enable performance metrics collection (CPU/RAM/Network)";
                };
              };
            };
            default = {};
            description = "Performance metrics";
          };

          systemLogs = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Enable system logs integration (journalctl)";
                };
              };
            };
            default = {};
            description = "System logs integration";
          };

          fileChanges = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Enable file changes tracking (inotify + git)";
                };
              };
            };
            default = {};
            description = "File changes tracking";
          };
        };
      };
      default = {};
      description = "Analysis and insights settings";
    };

    # AI & Machine Learning (v3.0.0 - Phase 7)
    ai = lib.mkOption {
      type = lib.types.submodule {
        options = {
          llm = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Enable LLM integration for AI-powered features";
                };
              };
            };
            default = {};
            description = "LLM integration";
          };

          anomalyDetection = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Enable anomaly detection for unusual patterns";
                };
              };
            };
            default = {};
            description = "Anomaly detection";
          };

          patternRecognition = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Enable pattern recognition for workflow analysis";
                };
              };
            };
            default = {};
            description = "Pattern recognition";
          };
        };
      };
      default = {};
      description = "AI and machine learning settings";
    };

    # Collaboration (v3.0.0 - Phase 7)
    collaboration = lib.mkOption {
      type = lib.types.submodule {
        options = {
          realtime = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Enable real-time collaboration and session sharing";
                };
              };
            };
            default = {};
            description = "Real-time collaboration";
          };
        };
      };
      default = {};
      description = "Collaboration settings";
    };

    # Visualization (v3.0.0 - Phase 7)
    visualization = lib.mkOption {
      type = lib.types.submodule {
        options = {
          heatmaps = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Enable heatmap visualizations (click maps, attention maps)";
                };
              };
            };
            default = {};
            description = "Heatmap visualizations";
          };
        };
      };
      default = {};
      description = "Visualization settings";
    };

    # Plugin System (v3.0.0 - Phase 7)
    plugins = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Enable plugin system and marketplace";
          };
        };
      };
      default = {};
      description = "Plugin system settings";
    };
  };
}
