{ config, lib, pkgs, ... }:

let
  # EXACT SAME ACTIVATION PATTERN AS stepRecorder
  cfg = config.googleCalendarWidget or {
    enable = true;
    autostart = true;
    width = 360;
    height = 500;
    profileDir = "$HOME/.local/share/google-calendar-widget";
  };

  calendarScript = pkgs.writeShellScriptBin "google-calendar-widget" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # CRITICAL: Set up GTK4, WebKit2 and all dependencies typelib paths (using webkitgtk_6_0 for GTK4 compatibility!)
    export GI_TYPELIB_PATH="${pkgs.gtk4}/lib/girepository-1.0:${pkgs.webkitgtk_6_0}/lib/girepository-1.0:${pkgs.libsoup_3}/lib/girepository-1.0:${pkgs.pango.out}/lib/girepository-1.0:${pkgs.cairo}/lib/girepository-1.0:${pkgs.gdk-pixbuf}/lib/girepository-1.0:${pkgs.graphene}/lib/girepository-1.0:${pkgs.harfbuzz}/lib/girepository-1.0:${pkgs.gobject-introspection}/lib/girepository-1.0"
    
    # CRITICAL: Enable TLS/SSL support by pointing to glib-networking modules
    export GIO_EXTRA_MODULES="${pkgs.glib-networking}/lib/gio/modules"
    
    # DEBUG: Enable verbose logging
    export WEBKIT_DEBUG="all"
    export G_MESSAGES_DEBUG="all"
    export GSK_RENDERER="cairo"
    export WEBKIT_DISABLE_COMPOSITING_MODE=1

    PROFILE_DIR="${cfg.profileDir}"
    eval PROFILE_DIR="$PROFILE_DIR"
    mkdir -p "$PROFILE_DIR"

    echo "=== Google Calendar Widget Starting ===" >&2
    echo "Profile Directory: $PROFILE_DIR" >&2
    echo "Timestamp: $(date)" >&2

    exec ${pkgs.python3.withPackages (ps: with ps; [
      pygobject3
    ])}/bin/python3 - << 'PY'
import gi, os, sys, logging, signal, traceback
from datetime import datetime

gi.require_version("Gtk", "4.0")
gi.require_version("WebKit", "6.0")

from gi.repository import Gtk, WebKit, Gio, GLib

PROFILE_DIR = os.path.expandvars(os.path.expanduser("${cfg.profileDir}"))
LOG_FILE = os.path.join(PROFILE_DIR, "debug.log")

# Ensure profile directory exists
os.makedirs(PROFILE_DIR, exist_ok=True)

# Set up comprehensive logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stderr)
    ]
)
logger = logging.getLogger(__name__)

# Signal handlers for crash detection
def signal_handler(signum, frame):
    logger.critical(f"Received signal {signum}")
    logger.critical(f"Stack trace:\n{'''.join(traceback.format_stack(frame))}")
    sys.exit(1)

signal.signal(signal.SIGSEGV, signal_handler)
signal.signal(signal.SIGABRT, signal_handler)

logger.info("=" * 60)
logger.info("Google Calendar Widget Starting")
logger.info(f"Profile Directory: {PROFILE_DIR}")
logger.info(f"Log File: {LOG_FILE}")
logger.info(f"Python Version: {sys.version}")
logger.info("=" * 60)

class CalendarApp(Gtk.Application):
    def __init__(self):
        super().__init__(
            application_id="org.nixos.GoogleCalendarWidget",
            flags=Gio.ApplicationFlags.FLAGS_NONE
        )
        logger.info("CalendarApp initialized")

    def do_activate(self):
        logger.info("CalendarApp.do_activate() called")
        
        try:
            win = Gtk.ApplicationWindow(application=self)
            win.set_title("Google Calendar")
            win.set_default_size(${toString cfg.width}, ${toString cfg.height})
            logger.info(f"Window created with size {${toString cfg.width}}x{${toString cfg.height}}")

            # Create WebView (WebContext is automatically managed in WebKit 6.0)
            logger.info("Creating WebView...")
            view = WebKit.WebView()
            logger.info("WebView created successfully")
            
            # Enable JavaScript and interactive web features for login
            logger.info("Configuring WebView settings...")
            settings = view.get_settings()
            settings.set_enable_javascript(True)
            settings.set_javascript_can_open_windows_automatically(True)
            settings.set_allow_file_access_from_file_urls(True)
            settings.set_enable_media(True)
            settings.set_enable_media_stream(True)
            settings.set_enable_developer_extras(True)  # Enable inspector
            logger.info("WebView settings configured")
            
            # Connect to load events
            view.connect("load-changed", self.on_load_changed)
            view.connect("load-failed", self.on_load_failed)
            view.connect("decide-policy", self.on_decide_policy)
            logger.info("Event handlers connected")
            
            # Connect to web process events
            view.connect("web-process-terminated", self.on_web_process_terminated)
            logger.info("Web process monitoring enabled")
            
            logger.info("Loading URI: https://calendar.google.com/calendar/u/0/r")
            view.load_uri("https://calendar.google.com/calendar/u/0/r")

            win.set_child(view)
            win.present()
            logger.info("Window presented")
            
        except Exception as e:
            logger.critical(f"Exception in do_activate: {e}")
            logger.critical(traceback.format_exc())
            raise

    def on_load_changed(self, view, load_event):
        event_names = {
            WebKit.LoadEvent.STARTED: "STARTED",
            WebKit.LoadEvent.REDIRECTED: "REDIRECTED",
            WebKit.LoadEvent.COMMITTED: "COMMITTED",
            WebKit.LoadEvent.FINISHED: "FINISHED"
        }
        event_name = event_names.get(load_event, f"UNKNOWN({load_event})")
        uri = view.get_uri()
        logger.info(f"Load event: {event_name} - URI: {uri}")
        
        if load_event == WebKit.LoadEvent.FINISHED:
            title = view.get_title()
            logger.info(f"Page loaded successfully - Title: {title}")

    def on_load_failed(self, view, load_event, failing_uri, error):
        logger.error(f"Load failed for URI: {failing_uri}")
        logger.error(f"Error: {error.message} (Code: {error.code})")
        return False

    def on_decide_policy(self, view, decision, decision_type):
        type_names = {
            WebKit.PolicyDecisionType.NAVIGATION_ACTION: "NAVIGATION_ACTION",
            WebKit.PolicyDecisionType.NEW_WINDOW_ACTION: "NEW_WINDOW_ACTION",
            WebKit.PolicyDecisionType.RESPONSE: "RESPONSE"
        }
        type_name = type_names.get(decision_type, f"UNKNOWN({decision_type})")
        
        if decision_type == WebKit.PolicyDecisionType.NAVIGATION_ACTION:
            nav_action = decision.get_navigation_action()
            request = nav_action.get_request()
            uri = request.get_uri()
            logger.info(f"Policy decision ({type_name}): {uri}")
        else:
            logger.info(f"Policy decision: {type_name}")
        
        return False

    def on_web_process_terminated(self, view, reason):
        reason_names = {
            WebKit.WebProcessTerminationReason.CRASHED: "CRASHED",
            WebKit.WebProcessTerminationReason.EXCEEDED_MEMORY_LIMIT: "EXCEEDED_MEMORY_LIMIT",
        }
        reason_name = reason_names.get(reason, f"UNKNOWN({reason})")
        logger.critical(f"Web process terminated! Reason: {reason_name}")
        logger.critical("This is likely the cause of the segmentation fault")

try:
    logger.info("Starting CalendarApp...")
    app = CalendarApp()
    logger.info("Running application...")
    app.run()
    logger.info("Application exited normally")
except Exception as e:
    logger.critical(f"Fatal exception: {e}")
    logger.critical(traceback.format_exc())
    sys.exit(1)
PY
  '';
in
{
  # SAME mkIf LOGIC AS stepRecorder
  config = lib.mkIf cfg.enable {

    environment.systemPackages = with pkgs; [
      gtk4
      webkitgtk_6_0
      libsoup_3
      glib-networking  # CRITICAL: Provides TLS/SSL support for HTTPS
      graphene
      pango
      cairo
      gdk-pixbuf
      harfbuzz
      python3
      gobject-introspection
      calendarScript
    ];

    systemd.user.services.google-calendar-widget = {
      description = "Google Calendar Widget";
      wantedBy = lib.optional cfg.autostart "default.target";
      serviceConfig = {
        ExecStart = "${calendarScript}/bin/google-calendar-widget";
        Restart = "on-failure";
        RestartSec = 3;
        # Capture all output to journald
        StandardOutput = "journal";
        StandardError = "journal";
        # Set log level to debug
        Environment = "SYSTEMD_LOG_LEVEL=debug";
      };
    };
  };
}
