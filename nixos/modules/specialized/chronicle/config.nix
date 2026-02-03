{ config, lib, pkgs, systemConfig, ... }:

let
  cfg = systemConfig.modules.specialized.chronicle;
  
  # Import library
  chronicleLib = import ./lib/default.nix { inherit lib pkgs; };
  
  # Determine backend based on mode
  backend = if cfg.mode == "automatic" then "x11" else "wayland";
  
  # Required packages
  recorderPackages = with pkgs; [
    # Core tools
    bash
    coreutils
    findutils
    jq
    zip
    unzip
    bc  # Math calculations for mouse tracking

    # X11 backend tools
    xorg.xinput
    xorg.xprop
    xorg.xrandr  # Multi-monitor detection
    xdotool
    maim
    imagemagick
    xev
    xbindkeys  # Hotkey support
    xprintidle  # Idle detection for smart step detection (v1.2+)

    # Wayland backend tools
    grim
    slurp
    sway  # Sway compositor (includes swaymsg for window detection)
    wtype
    kdePackages.spectacle
    libinput

    # Notifications and dialogs
    libnotify  # Desktop notifications
    xdg-utils  # xdg-open for auto-open reports
    
    # Phase 2: PDF Export (optional, graceful fallback)
    # wkhtmltopdf  # Uncomment for best PDF quality
    # python3Packages.weasyprint  # Alternative PDF generator
    # chromium  # Fallback PDF generator
    
    # Phase 3: Enhanced UX (v1.1+)
    # Video recording dependencies (optional)
  ] ++ lib.optionals (cfg.recording.enableVideo or false) [
    ffmpeg  # Video recording and processing
    gawk    # Text processing for video utils
  ] ++ lib.optionals ((cfg.recording.enableVideo or false) && backend == "wayland") [
    wf-recorder  # Wayland video recording
  ] ++ lib.optionals (cfg.recording.enableAudio or false) [
    # Audio recording dependencies
    pulseaudio  # For pactl command (works with PipeWire too)
    alsa-utils  # ALSA fallback
  ] ++ lib.optionals (cfg.recording.enableKeyboard or false) [
    # Keyboard recording (X11 only for now)
    xorg.xmodmap  # Key name mapping
    
    # GUI dependencies (if enabled)
  ] ++ lib.optionals (cfg.gui.enableGtk or false) [
    python3
    python3Packages.pygobject3
    python3Packages.pydbus
    gtk4
    libadwaita
    gobject-introspection
    graphene
    pango
    cairo
    gdk-pixbuf
    harfbuzz
  ] ++ lib.optionals (cfg.gui.enableTray or false) [
    yad
  ] ++ lib.optionals (cfg.privacy.enableOCR or false) [
    tesseract
  ] ++ [
    # Phase 4: v1.2.0 dependencies
    python3Packages.pillow  # Screenshot annotations (PIL)
  ] ++ [
    # GUI dialog tools (optional, graceful degradation)
    zenity  # GNOME dialogs (moved to top-level)
    kdePackages.kdialog  # KDE dialogs
  ];

  # Main recorder script
  recorderScript = import ./scripts/main.nix {
    inherit lib pkgs cfg chronicleLib backend;
  };

  # GUI script (if enabled)
  guiScript = lib.optionalAttrs (cfg.gui.enableGtk or false) (
    import ./gui/gtk4-app.nix { inherit lib pkgs cfg; }
  );

  # Tray script (if enabled)
  trayScript = lib.optionalAttrs (cfg.gui.enableTray or false) (
    import ./gui/tray.nix { inherit lib pkgs cfg; }
  );

  # API module (v2.0.0 - Phase 5)
  apiModule = lib.optionalAttrs (cfg.api.enable or false) (
    import ./api/default.nix { inherit lib pkgs cfg; }
  );

  # Integrations module (v2.0.0 - Phase 5)
  integrationsModule = import ./integrations/default.nix { inherit lib pkgs cfg; };

  # Cloud upload module (v2.0.0 - Phase 5)
  cloudModule = import ./cloud/default.nix { inherit lib pkgs cfg; };

  # Email module (v2.0.0 - Phase 5)
  emailModule = import ./email/default.nix { inherit lib pkgs cfg; };

  # Analysis module (v2.0.0 - Phase 5)
  analysisModule = import ./analysis/default.nix { inherit lib pkgs cfg; };

  # Search & Comparison module (v2.0.0 - Phase 5)
  searchModule = import ./search/default.nix { inherit config lib pkgs systemConfig; };

  # Export recorderScript for commands.nix
  recorderScriptExport = { inherit recorderScript; };

in
{
  config = lib.mkIf cfg.enable {
    # Install packages
    environment.systemPackages = recorderPackages ++ [
      recorderScript
    ] ++ lib.optional (cfg.gui.enableGtk or false) guiScript
      ++ lib.optional (cfg.gui.enableTray or false) trayScript
      ++ lib.optionals (cfg.api.enable or false) [
        apiModule.server
        apiModule.client
      ]
      ++ lib.optionals (cfg.integrations.github.enable or false) [
        integrationsModule.github
      ]
      ++ lib.optionals (cfg.integrations.gitlab.enable or false) [
        integrationsModule.gitlab
      ]
      ++ lib.optionals (cfg.integrations.jira.enable or false) [
        integrationsModule.jira
      ]
      ++ lib.optionals (cfg.cloud.s3.enable or false) [
        cloudModule.s3
      ]
      ++ lib.optionals (cfg.cloud.nextcloud.enable or false) [
        cloudModule.nextcloud
      ]
      ++ lib.optionals (cfg.cloud.dropbox.enable or false) [
        cloudModule.dropbox
      ]
      ++ lib.optionals (cfg.email.enable or false) [
        emailModule.smtp
      ]
      ++ lib.optionals (cfg.analysis.performanceMetrics.enable or false) [
        analysisModule.performanceMetrics
      ]
      ++ lib.optionals (cfg.analysis.systemLogs.enable or false) [
        analysisModule.systemLogs
      ]
      ++ lib.optionals (cfg.analysis.fileChanges.enable or false) [
        analysisModule.fileChanges
      ];

    # User environment variables
    environment.variables = {
      CHRONICLE_OUTPUT_DIR = cfg.outputDir;
      CHRONICLE_FORMAT = cfg.format;
    } // lib.optionalAttrs (cfg.api.enable or false) {
      CHRONICLE_API_HOST = cfg.api.host;
      CHRONICLE_API_PORT = toString cfg.api.port;
    };
  };
}
