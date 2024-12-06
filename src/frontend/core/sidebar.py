## Path: src/frontend/core/sidebar.py

import logging
from gi.repository import Gtk

class Sidebar(Gtk.ListBox):
    """Sidebar for the NixOS Control Center."""

    def __init__(self, content_manager):
        super().__init__()
        self.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.content_manager = content_manager

        for label in self.content_manager.view_map.keys():
            self.append(Gtk.Label(label=label.capitalize()))

        self.connect("row-selected", self.on_selection_changed)

    def on_selection_changed(self, listbox, row):
        """Handle sidebar item selection and display corresponding view."""
        if row:
            label = row.get_child().get_text().lower().replace(" ", "_")
            logging.info(f"Selected label: {label}")
            self.content_manager.switch_view(label)


