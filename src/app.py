## Path: src/app.py

"""
Main application class for the NixOS Control Center.
"""

import gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gtk
from src.frontend.core.main_window import MainWindow  # Import the main window class

class NixOsControlCenterApp:
    """Main application class for the NixOS Control Center."""

    def __init__(self):
        """Initialize the application."""
        print("Initializing NixOsControlCenterApp...")
        self.application = Gtk.Application(application_id="com.nixos.controlcenter")

    def run(self):
        """Run the GTK application."""
        self.application.connect("activate", self.on_activate)
        self.application.run(None)

    def on_activate(self, app):
        """Callback when the application is activated."""
        print("Application activated!")
        window = MainWindow(application=app)
        window.present()
