## Path: src/frontend/views/generations_view.py

from gi.repository import Gtk
import logging
from src.backend.services.generation_manager import GenerationManager
from datetime import datetime

# Frontend logger configuration
logger = logging.getLogger(__name__)

class GenerationsView(Gtk.Box):
    def __init__(self, root, debug_mode: bool = False):
        super().__init__(orientation=Gtk.Orientation.VERTICAL)
        self.root = root
        
        # Set logging level based on debug mode
        if debug_mode:
            logger.setLevel(logging.DEBUG)
        else:
            logger.setLevel(logging.INFO)
        
        logger.debug("Initializing GenerationsView")
        
        # Create a section header
        header = Gtk.Label(label="System Generations")
        header.set_margin_bottom(10)
        header.set_margin_top(10)
        header.set_justify(Gtk.Justification.CENTER)
        self.append(header)

        # Create a list box to display generations
        self.generations_list = Gtk.ListBox()
        self.append(self.generations_list)

        # Placeholder text for now
        self.no_generations_label = Gtk.Label(label="No generations available")
        self.generations_list.append(self.no_generations_label)

        # Initialize the generation manager
        self.generation_manager = GenerationManager(debug_mode)

        # Fetch actual generation data from the backend
        self.fetch_generations()

    def fetch_generations(self):
        """Fetch actual system generations from the backend."""
        generations = self.generation_manager.get_generations()
        
        # Clear existing list
        while self.generations_list.get_first_child():
            self.generations_list.remove(self.generations_list.get_first_child())
        
        if generations:
            # System Generations Section
            system_header = Gtk.Label(label="NixOS System Generations")
            system_header.set_margin_top(10)
            system_header.set_margin_bottom(5)
            system_header.add_css_class("heading")
            self.generations_list.append(system_header)

            for gen in generations:
                if gen['type'] == "system":
                    self._add_system_generation(gen)

            # Add Flake Generations section
            flake_header = Gtk.Label(label="Flake Generations")
            flake_header.set_margin_top(10)
            flake_header.set_margin_bottom(5)
            flake_header.add_css_class("heading")
            self.generations_list.append(flake_header)

            # Add flake generations
            for gen in generations:
                if gen['type'] == "flake":
                    self._add_flake_generation(gen)

            # Add Legacy Generations section
            legacy_header = Gtk.Label(label="Legacy Generations")
            legacy_header.set_margin_top(20)
            legacy_header.set_margin_bottom(5)
            legacy_header.add_css_class("heading")
            self.generations_list.append(legacy_header)

            # Add legacy generations
            for gen in generations:
                if gen['type'] == "legacy":
                    self._add_legacy_generation(gen)
        else:
            self.generations_list.append(self.no_generations_label)

    def _add_flake_generation(self, generation):
        """Add a flake generation entry with proper formatting."""
        gen_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=5)
        gen_container.set_margin_start(10)
        gen_container.set_margin_end(10)
        gen_container.set_margin_top(5)

        # Name and path info
        info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        name_label = Gtk.Label(label=f"Name: {generation['name']}")
        name_label.set_xalign(0)
        path_label = Gtk.Label(label=f"Path: {generation['store_path']}")
        path_label.set_xalign(0)
        
        info_box.append(name_label)
        info_box.append(path_label)
        
        # Action buttons
        button_box = self._create_action_buttons(generation)
        
        # Add everything to container
        gen_container.append(info_box)
        gen_container.append(button_box)
        
        self.generations_list.append(gen_container)

    def _add_legacy_generation(self, generation):
        """Add a legacy generation entry with proper formatting."""
        gen_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        gen_box.set_margin_start(10)
        gen_box.set_margin_end(10)
        gen_box.set_margin_top(5)
        
        # Legacy info
        info_label = Gtk.Label(
            label=f"Generation #{generation['number']} - {generation['date']} {generation['status']}"
        )
        info_label.set_xalign(0)
        gen_box.append(info_label)
        
        # Action buttons
        button_box = self._create_action_buttons(generation)
        gen_box.append(button_box)
        
        self.generations_list.append(gen_box)

    def _add_system_generation(self, generation):
        """Add a system generation entry with proper formatting."""
        gen_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        gen_box.set_margin_start(15)
        gen_box.set_margin_end(15)
        gen_box.set_margin_top(5)
        gen_box.add_css_class("generation-container")

        # Generation info
        info_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        
        # Generation number and date
        gen_label = Gtk.Label(
            label=f"Generation #{generation['number']} - {generation['date']}"
        )
        gen_label.set_xalign(0)
        if generation['status'] == '(current)':
            gen_label.add_css_class("current-generation")
        
        info_box.append(gen_label)
        gen_box.append(info_box)
        
        # Action buttons
        button_box = self._create_action_buttons(generation)
        gen_box.append(button_box)
        
        self.generations_list.append(gen_box)

    def _create_action_buttons(self, generation):
        """Create a consistent set of action buttons."""
        button_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=5)
        
        rename_button = Gtk.Button(label="Rename")
        rename_button.connect("clicked", self.on_rename_clicked, generation)
        
        lock_button = Gtk.Button(label="Lock")
        lock_button.connect("clicked", self.on_lock_clicked, generation)
        
        analyze_button = Gtk.Button(label="Analyze")
        analyze_button.connect("clicked", self.on_analyze_clicked, generation)
        
        delete_button = Gtk.Button(label="Delete")
        delete_button.connect("clicked", self.on_delete_clicked, generation)
        
        for button in [rename_button, lock_button, analyze_button, delete_button]:
            button_box.append(button)
        
        return button_box

    def on_rename_clicked(self, button, generation):
        """Handle rename action."""
        logger.info(f"Renaming generation: {generation}")
        
        # Create a dialog for name input
        dialog = Gtk.Dialog(
            title="Rename Generation",
            transient_for=self.get_root(),
            modal=True,
            use_header_bar=True
        )
        
        dialog.add_button("Cancel", Gtk.ResponseType.CANCEL)
        dialog.add_button("Rename", Gtk.ResponseType.OK)
        
        # Add content area
        content_area = dialog.get_content_area()
        content_area.set_spacing(6)
        content_area.set_margin_top(6)
        content_area.set_margin_bottom(6)
        content_area.set_margin_start(6)
        content_area.set_margin_end(6)
        
        # Add description label
        description = Gtk.Label()
        description.set_markup(
            f"Enter new name for Generation #{generation['number']}\n"
            "<small>Allowed: letters, numbers, spaces, and -_.</small>"
        )
        content_area.append(description)
        
        # Add entry for new name
        entry = Gtk.Entry()
        entry.set_max_length(50)  # Limit name length
        if 'name' in generation:
            entry.set_text(generation['name'])
        content_area.append(entry)
        
        # Add error label (hidden by default)
        error_label = Gtk.Label()
        error_label.set_markup("<small><span color='red'></span></small>")
        error_label.set_visible(False)
        content_area.append(error_label)
        
        def get_generation_data(row):
            """Extract generation data from ListBoxRow."""
            if hasattr(row, 'generation_data'):
                return row.generation_data
            return None
        
        def validate_name(name):
            """Validate the entered name."""
            if not name or len(name.strip()) == 0:
                return "Name cannot be empty"
            
            if len(name) > 50:
                return "Name is too long (max 50 characters)"
            
            # Check for valid characters
            import re
            if not re.match(r'^[a-zA-Z0-9\s\-_.]+$', name):
                return "Name contains invalid characters"
            
            # Check for existing names
            existing_names = []
            for row in self.generations_list:
                gen_data = get_generation_data(row)
                if gen_data and gen_data.get('number') != generation['number']:
                    existing_names.append(gen_data.get('name', ''))
            
            if name in existing_names:
                return "This name is already in use"
            
            return None

        def on_text_changed(entry):
            """Handle text changes in the entry."""
            name = entry.get_text().strip()
            error = validate_name(name)
            
            # Update error label
            if error:
                error_label.set_markup(f"<small><span color='red'>{error}</span></small>")
                error_label.set_visible(True)
            else:
                error_label.set_visible(False)
            
            # Update OK button sensitivity
            rename_button = dialog.get_widget_for_response(Gtk.ResponseType.OK)
            if rename_button:
                rename_button.set_sensitive(error is None)

        def on_response(dialog, response):
            """Handle dialog response."""
            if response == Gtk.ResponseType.OK:
                new_name = entry.get_text().strip()
                error = validate_name(new_name)
                
                if error is None:
                    # Try to rename the generation
                    success = self.generation_manager.rename_generation(generation, new_name)
                    
                    if success:
                        # Show success message
                        success_dialog = Gtk.MessageDialog(
                            transient_for=self.get_root(),
                            message_type=Gtk.MessageType.INFO,
                            buttons=Gtk.ButtonsType.OK,
                            text=f"Generation #{generation['number']} renamed successfully"
                        )
                        success_dialog.present()
                        success_dialog.connect("response", lambda d, r: d.destroy())
                        
                        # Refresh the generations list
                        self.fetch_generations()
                    else:
                        # Show error message
                        error_dialog = Gtk.MessageDialog(
                            transient_for=self.get_root(),
                            message_type=Gtk.MessageType.ERROR,
                            buttons=Gtk.ButtonsType.OK,
                            text="Failed to rename generation",
                            secondary_text="Please check the logs for more information"
                        )
                        error_dialog.present()
                        error_dialog.connect("response", lambda d, r: d.destroy())
            
            dialog.destroy()

        # Connect signals
        entry.connect('changed', on_text_changed)
        dialog.connect('response', on_response)
        
        # Show dialog
        dialog.set_default_size(300, -1)
        dialog.present()

    def on_lock_clicked(self, button, generation):
        """Handle lock action."""
        logger.info(f"Locking generation: {generation}")
        # Add the logic for locking here

    def on_analyze_clicked(self, button, generation):
        """Handle analyze action."""
        logger.info(f"Analyzing generation: {generation}")
        # Add the logic for analyzing here

    def on_delete_clicked(self, button, generation):
        """Handle delete action."""
        logger.info(f"Deleting generation: {generation}")
        # Add the logic for deleting here

    def create_generations_view(self):
        """Create the generations view with a scrollable list."""
        scrolled_window = Gtk.ScrolledWindow()
        scrolled_window.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        scrolled_window.set_min_content_height(400)  # Mindesthöhe für die Anzeige

        self.generations_list = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        scrolled_window.set_child(self.generations_list)

        return scrolled_window

