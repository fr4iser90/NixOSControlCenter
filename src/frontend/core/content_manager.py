## Path: src/frontend/core/content_manager.py

import logging
from gi.repository import Gtk
from .state_manager.state_manager import StateManager

class ContentManager:
    def __init__(self, content_stack, root, view_map):
        self.content_stack = content_stack
        self.root = root
        self.view_map = view_map
        self.view_instances = {}
        self.state_manager = StateManager()
        self.previous_child = None  # Track the previous visible child

    def switch_view(self, label):
        """Switch to the specified view."""
        logging.info(f"Switching to view: {label}")
        
        if label in self.view_map:
            view_class = self.view_map.get(label)
            if view_class:
                if self.content_stack.get_visible_child_name() != label:
                    # Save the current state before switching
                    if self.previous_child in self.view_instances:
                        current_view = self.view_instances[self.previous_child]
                        if hasattr(current_view, 'get_state'):
                            state = current_view.get_state()
                            self.state_manager.save_state(self.previous_child, state)

                    if label not in self.view_instances:
                        logging.info(f"Creating new view for: {label}")
                        view_instance = view_class(self.root)
                        self.content_stack.add_named(view_instance, label)
                        self.view_instances[label] = view_instance
                    else:
                        logging.info(f"View for {label} already exists in stack.")
                        
                    # Restore the state for the new view
                    view_instance = self.view_instances[label]
                    if hasattr(view_instance, 'set_state'):
                        state = self.state_manager.get_state(label)
                        view_instance.set_state(state)

                    self.content_stack.set_visible_child_name(label)
                    self.manage_backend_operations(label)
                else:
                    logging.info(f"View for {label} is already visible.")
            else:
                logging.error(f"No view found for label: {label}")
        else:
            logging.error(f"Label {label} not in view_map.")

    def manage_backend_operations(self, visible_child):
        """Manage backend operations when switching views."""
        # Stop backend operations for the previous view
        if self.previous_child and self.previous_child != visible_child:
            self.stop_backend_operations(self.previous_child)
        
        # Start backend operations for the current view
        self.start_backend_operations(visible_child)
        
        # Update the previous child
        self.previous_child = visible_child

    def start_backend_operations(self, label):
        """Start backend operations for a specific view."""
        if label in self.view_instances:
            view_instance = self.view_instances[label]
            if hasattr(view_instance, 'start_backend_operations'):
                view_instance.start_backend_operations()

    def stop_backend_operations(self, label):
        """Stop backend operations for a specific view."""
        if label in self.view_instances:
            view_instance = self.view_instances[label]
            if hasattr(view_instance, 'stop_backend_operations'):
                view_instance.stop_backend_operations()