## Path: src/frontend/core/main_window.py

from gi.repository import Gtk
from .sidebar import Sidebar
from .content_manager import ContentManager
from src.frontend.modules.dashboard.view import DashboardView
from src.frontend.modules.generations.view import GenerationsView
from src.frontend.modules.configuration.view import ConfigurationView


class MainWindow(Gtk.ApplicationWindow):
    def __init__(self, application):
        super().__init__(application=application, title="NixOS Control Center")
        self.set_default_size(800, 600)

        main_layout = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        content_stack = Gtk.Stack()
        content_stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)

        view_map = {
            "dashboard": DashboardView,
            "generation": GenerationsView,
            "configuration": ConfigurationView,
            # Add other views here
        }

        self.content_manager = ContentManager(content_stack, self, view_map)
        sidebar = Sidebar(self.content_manager)

        main_layout.append(sidebar)
        main_layout.append(content_stack)

        self.set_child(main_layout)