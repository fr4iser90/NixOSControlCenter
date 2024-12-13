from gi.repository import Gtk, GLib
import logging
from src.backend.services.generation_manager import GenerationManager
from src.frontend.core.theme_manager import ThemeManager
from datetime import datetime

logger = logging.getLogger(__name__)

class GenerationsView(Gtk.Box):
    def __init__(self, root):
        super().__init__(orientation=Gtk.Orientation.VERTICAL)
        self.root = root
        self.root.set_title("NixOS Control Center - System Generations")
        self.generation_manager = GenerationManager()
        
        # Header
        header = Gtk.Label(label="NixOS System Generations")
        header.get_style_context().add_class("header")
        self.append(header)
        
        # Toolbar mit Aktionen
        self.create_toolbar()
        
        # ScrolledWindow für die Liste
        scrolled_window = Gtk.ScrolledWindow()
        scrolled_window.set_vexpand(True)
        scrolled_window.set_policy(
            Gtk.PolicyType.NEVER,
            Gtk.PolicyType.AUTOMATIC
        )
        
        # Container für die Generationen-Liste
        self.generations_list = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.generations_list.get_style_context().add_class("list-container")
        
        scrolled_window.set_child(self.generations_list)
        self.append(scrolled_window)
        
        # Status-Bar
        self.status_bar = Gtk.Label()
        self.status_bar.get_style_context().add_class("status-bar")
        self.append(self.status_bar)
        
        # Generationen laden
        self.load_generations()
        
        # Auto-Refresh alle 30 Sekunden
        GLib.timeout_add_seconds(30, self.refresh_generations)

    def create_toolbar(self):
        """Erstellt die Toolbar mit Aktionen"""
        toolbar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        toolbar.get_style_context().add_class("toolbar")
        
        refresh_btn = Gtk.Button(label="Refresh")
        refresh_btn.connect("clicked", lambda _: self.refresh_generations())
        
        cleanup_btn = Gtk.Button(label="Cleanup Old")
        cleanup_btn.connect("clicked", self.on_cleanup_clicked)
        
        toolbar.append(refresh_btn)
        toolbar.append(cleanup_btn)
        
        self.append(toolbar)

    def load_generations(self):
        """Lädt und zeigt alle System-Generationen"""
        try:
            # Bestehende Einträge entfernen
            while self.generations_list.get_first_child():
                self.generations_list.remove(self.generations_list.get_first_child())
            
            generations = self.generation_manager.get_generations()
            
            for generation in generations:
                self._add_system_generation(generation)
            
            self.update_status(f"Loaded {len(generations)} generations")
            
        except Exception as e:
            logger.error(f"Error loading generations: {e}")
            self.show_error(f"Failed to load generations: {str(e)}")

    def refresh_generations(self):
        """Aktualisiert die Generationen-Liste"""
        self.load_generations()
        return True  # Wichtig für GLib.timeout_add_seconds

    def on_cleanup_clicked(self, button):
        """Behandelt Klicks auf den Cleanup-Button"""
        dialog = Gtk.MessageDialog(
            transient_for=self.root,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.YES_NO,
            text="Clean up old generations?",
            secondary_text="This will remove all non-current, non-locked generations."
        )
        
        response = dialog.run()
        dialog.destroy()
        
        if response == Gtk.ResponseType.YES:
            try:
                removed = self.generation_manager.cleanup_old_generations()
                self.update_status(f"Removed {removed} old generations")
                self.load_generations()
            except Exception as e:
                self.show_error(f"Cleanup failed: {str(e)}")

    def _add_system_generation(self, generation):
        """Add a system generation entry with proper formatting"""
        list_item = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        list_item.get_style_context().add_class("list-item")
        
        # Info Box mit fixer Breite
        info_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        info_box.set_size_request(600, -1)  # Fixe Breite für Info-Box
        
        # Generation Label
        gen_label = Gtk.Label(
            label=f"#{generation['number']} {generation.get('title', 'GamingSetup')} | {generation.get('date', '')} | Kernel: {generation.get('kernel', '')}"
        )
        if generation.get('status') == 'current':
            gen_label.set_text(gen_label.get_text() + " (current)")
        
        gen_label.set_xalign(0)
        gen_label.get_style_context().add_class("generation-label")
        
        info_box.append(gen_label)
        
        # Button-Gruppe
        button_group = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        button_group.get_style_context().add_class("button-group")
        button_group.set_spacing(8)  # Konsistenter Abstand zwischen Buttons
        
        buttons = [
            ("Rename", "edit-button", self.on_rename_clicked),
            ("Lock", "lock-button", self.on_lock_clicked),
            ("Analyze", "analyze-button", self.on_analyze_clicked),
            ("Delete", "delete-button", self.on_delete_clicked)
        ]
        
        for label, style_class, callback in buttons:
            button = Gtk.Button(label=label)
            button.get_style_context().add_class("button")
            button.get_style_context().add_class(style_class)
            button.connect("clicked", callback, generation)
            button_group.append(button)
        
        list_item.append(info_box)
        list_item.append(button_group)
        
        self.generations_list.append(list_item)

    def on_rename_clicked(self, button, generation):
        """Behandelt Klicks auf den Rename-Button"""
        dialog = Gtk.Dialog(
            title="Rename Generation",
            transient_for=self.root,
            modal=True
        )
        
        box = dialog.get_content_area()
        entry = Gtk.Entry()
        entry.set_text(generation.get('title', ''))
        box.append(entry)
        
        dialog.add_button("Cancel", Gtk.ResponseType.CANCEL)
        dialog.add_button("Rename", Gtk.ResponseType.OK)
        
        dialog.show()
        response = dialog.run()
        
        if response == Gtk.ResponseType.OK:
            new_name = entry.get_text()
            try:
                self.generation_manager.rename_generation(generation['number'], new_name)
                self.load_generations()
            except Exception as e:
                self.show_error(f"Failed to rename generation: {str(e)}")
        
        dialog.destroy()

    def on_lock_clicked(self, button, generation):
        """Behandelt Klicks auf den Lock-Button"""
        try:
            self.generation_manager.toggle_lock_generation(generation['number'])
            self.load_generations()
        except Exception as e:
            self.show_error(f"Failed to toggle lock: {str(e)}")

    def on_analyze_clicked(self, button, generation):
        """Behandelt Klicks auf den Analyze-Button"""
        try:
            diff = self.generation_manager.analyze_generation(generation['number'])
            self.show_diff_dialog(diff)
        except Exception as e:
            self.show_error(f"Failed to analyze generation: {str(e)}")

    def on_delete_clicked(self, button, generation):
        """Behandelt Klicks auf den Delete-Button"""
        if generation.get('status') == 'current':
            self.show_error("Cannot delete current generation")
            return
            
        dialog = Gtk.MessageDialog(
            transient_for=self.root,
            message_type=Gtk.MessageType.WARNING,
            buttons=Gtk.ButtonsType.YES_NO,
            text=f"Delete generation #{generation['number']}?",
            secondary_text="This action cannot be undone."
        )
        
        response = dialog.run()
        dialog.destroy()
        
        if response == Gtk.ResponseType.YES:
            try:
                self.generation_manager.delete_generation(generation['number'])
                self.load_generations()
            except Exception as e:
                self.show_error(f"Failed to delete generation: {str(e)}")

    def show_diff_dialog(self, diff):
        """Zeigt einen Dialog mit Generations-Unterschieden"""
        dialog = Gtk.Dialog(
            title="Generation Differences",
            transient_for=self.root,
            modal=True
        )
        dialog.set_default_size(600, 400)
        
        scroll = Gtk.ScrolledWindow()
        text_view = Gtk.TextView()
        text_view.get_buffer().set_text(diff)
        text_view.set_editable(False)
        text_view.get_style_context().add_class("monospace")
        
        scroll.set_child(text_view)
        dialog.get_content_area().append(scroll)
        
        dialog.add_button("Close", Gtk.ResponseType.CLOSE)
        dialog.run()
        dialog.destroy()

    def show_error(self, message):
        """Zeigt einen Fehlerdialog"""
        dialog = Gtk.MessageDialog(
            transient_for=self.root,
            message_type=Gtk.MessageType.ERROR,
            buttons=Gtk.ButtonsType.OK,
            text="Error",
            secondary_text=message
        )
        dialog.run()
        dialog.destroy()

    def update_status(self, message):
        """Aktualisiert die Status-Bar"""
        self.status_bar.set_text(message)