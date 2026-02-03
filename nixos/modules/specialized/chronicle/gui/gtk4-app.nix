{ lib, pkgs, cfg }:

pkgs.writeShellScriptBin "chronicle-gui" ''
  #!/usr/bin/env bash
  export GI_TYPELIB_PATH="${pkgs.gtk4}/lib/girepository-1.0:${pkgs.libadwaita}/lib/girepository-1.0:${pkgs.pango.out}/lib/girepository-1.0:${pkgs.cairo}/lib/girepository-1.0:${pkgs.gdk-pixbuf}/lib/girepository-1.0:${pkgs.graphene}/lib/girepository-1.0:${pkgs.harfbuzz}/lib/girepository-1.0:${pkgs.gobject-introspection}/lib/girepository-1.0"
  
  exec ${pkgs.python3.withPackages (ps: with ps; [ pygobject3 pydbus ])}/bin/python3 - << 'PYTHON_EOF'
import json, os, subprocess, sys
import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GLib, Gio

class StepRecorderApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id='org.nixos.StepRecorder', flags=Gio.ApplicationFlags.FLAGS_NONE)
        self.window = None

    def do_activate(self):
        if not self.window:
            self.window = Adw.ApplicationWindow(application=self)
            self.window.set_title("Step Recorder")
            self.window.set_default_size(500, 400)
            
            main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            header = Adw.HeaderBar()
            main_box.append(header)
            
            content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
            content.set_margin_top(24)
            content.set_margin_bottom(24)
            content.set_margin_start(24)
            content.set_margin_end(24)
            
            status_label = Gtk.Label(label="⚫ Not Recording")
            status_label.add_css_class("title-1")
            content.append(status_label)
            
            button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
            button_box.set_halign(Gtk.Align.CENTER)
            button_box.set_margin_top(12)
            
            start_btn = Gtk.Button(label="Start Recording")
            start_btn.add_css_class("suggested-action")
            start_btn.connect('clicked', lambda b: subprocess.Popen(['chronicle', 'start', '--daemon']))
            button_box.append(start_btn)
            
            stop_btn = Gtk.Button(label="Stop Recording")
            stop_btn.add_css_class("destructive-action")
            stop_btn.connect('clicked', lambda b: subprocess.run(['chronicle', 'stop']))
            button_box.append(stop_btn)
            
            content.append(button_box)
            main_box.append(content)
            
            self.window.set_content(main_box)
        self.window.present()

if __name__ == '__main__':
    app = StepRecorderApp()
    sys.exit(app.run(sys.argv))
PYTHON_EOF
''
