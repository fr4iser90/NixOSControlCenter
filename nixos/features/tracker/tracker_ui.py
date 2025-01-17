#!/usr/bin/env python3

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, GObject, GLib
import json
import os
from pathlib import Path

class RoadmapTrackerApp(Gtk.ApplicationWindow):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        
        # Window setup
        self.set_default_size(800, 600)
        self.set_title("Multi-Roadmap Tracker")
        
        # Main container
        self.main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.add(self.main_box)
        
        # Tree view for roadmaps
        self.tree_view = Gtk.TreeView()
        self.tree_model = Gtk.TreeStore(str, str, str)  # Name, Status, Deadline
        self.tree_view.set_model(self.tree_model)
        
        # Add columns
        renderer = Gtk.CellRendererText()
        column = Gtk.TreeViewColumn("Task", renderer, text=0)
        self.tree_view.append_column(column)
        
        # Add to main window
        scroll = Gtk.ScrolledWindow()
        scroll.add(self.tree_view)
        self.main_box.pack_start(scroll, True, True, 0)
        
        # Load data
        self.load_roadmaps()
        
    def load_roadmaps(self):
        config_dir = Path.home() / ".config" / "multi-roadmap-tracker"
        roadmap_file = config_dir / "roadmaps.json"
        
        if not roadmap_file.exists():
            print("No roadmaps found")
            return
            
        with open(roadmap_file) as f:
            data = json.load(f)
            
        for roadmap in data['roadmaps']:
            roadmap_iter = self.tree_model.append(None, [roadmap['name'], "", ""])
            for task in roadmap['tasks']:
                self.tree_model.append(roadmap_iter, [
                    task['name'],
                    task.get('status', ''),
                    task.get('deadline', '')
                ])

class TrackerApplication(Gtk.Application):
    def __init__(self):
        super().__init__(application_id='org.nixos.tracker')
        
    def do_activate(self):
        win = RoadmapTrackerApp(application=self)
        win.show_all()

if __name__ == "__main__":
    app = TrackerApplication()
    app.run(None)
