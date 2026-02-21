#!/usr/bin/env python3
"""
GNOME GUI (GTK4/Python)
Purpose: Desktop GUI für GNOME
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gio, GLib

class ExampleWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="Example Module")
        self.set_default_size(800, 600)
        
        # Create UI
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.set_margin_start(10)
        box.set_margin_end(10)
        box.set_margin_top(10)
        box.set_margin_bottom(10)
        
        label = Gtk.Label(label="Example Module")
        label.add_css_class("title-1")
        box.append(label)
        
        button_list = Gtk.Button(label="List Items")
        button_list.connect("clicked", self.on_list_clicked)
        box.append(button_list)
        
        button_add = Gtk.Button(label="Add Item")
        button_add.connect("clicked", self.on_add_clicked)
        box.append(button_add)
        
        self.set_child(box)
    
    def on_list_clicked(self, button):
        # Call CLI command or API
        print("List items clicked")
    
    def on_add_clicked(self, button):
        # Call CLI command or API
        print("Add item clicked")

class ExampleApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="org.nixos.example-module")
    
    def do_activate(self):
        win = ExampleWindow(self)
        win.present()

if __name__ == "__main__":
    app = ExampleApp()
    app.run()
