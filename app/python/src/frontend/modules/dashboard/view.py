## Path: src/frontend/views/dashboard_view.py

import logging
from gi.repository import Gtk, GLib
from src.backend.services.system_monitor import SystemMonitor
from src.frontend.core.theme_manager import ThemeManager


class DashboardView(Gtk.Box):
    def __init__(self, root):
        super().__init__(orientation=Gtk.Orientation.VERTICAL)
        self.root = root
        self.root.set_title("NixOS Control Center - Dashboard")
        logging.info("DashboardView initialized")
        self.create_section_header()
        self.create_metrics_box()
        self.monitor = SystemMonitor()

    def create_section_header(self):
        header = Gtk.Label(label="System Overview")
        ThemeManager.apply_header_style(header)
        header.set_margin_bottom(ThemeManager.get_margin())
        header.set_margin_top(ThemeManager.get_margin())
        header.set_justify(Gtk.Justification.CENTER)
        self.append(header)

    def create_metrics_box(self):
        metrics_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, 
                            spacing=ThemeManager.get_margin("sm"))
        ThemeManager.apply_panel_style(metrics_box)
        
        # Erstelle Labels mit konsistentem Styling
        self.cpu_label = self._create_metric_label("CPU Usage: Loading...")
        self.memory_label = self._create_metric_label("Memory Usage: Loading...")
        self.disk_label = self._create_metric_label("Disk Usage: Loading...")
        self.network_label = self._create_metric_label("Network Activity: Loading...")
        
        metrics_box.append(self.cpu_label)
        metrics_box.append(self.memory_label)
        metrics_box.append(self.disk_label)
        metrics_box.append(self.network_label)
        self.append(metrics_box)

    def _create_metric_label(self, text):
        """Hilfsmethode zum Erstellen einheitlich gestylter Metric-Labels"""
        label = Gtk.Label(label=text)
        label.get_style_context().add_class("metric-label")
        label.set_margin_start(ThemeManager.get_margin("sm"))
        label.set_margin_end(ThemeManager.get_margin("sm"))
        return label

    def update_dashboard(self, system_metrics):
        logging.info(f"Updating dashboard with: {system_metrics}")
        self.cpu_label.set_text(f"CPU Usage: {system_metrics['cpu']}%")
        self.memory_label.set_text(f"Memory Usage: {system_metrics['memory']}%")
        self.disk_label.set_text(f"Disk Usage: {system_metrics['disk']}%")
        self.network_label.set_text(f"Network Activity: Sent {system_metrics['network'][0]} bytes, Received {system_metrics['network'][1]} bytes")

    def start_backend_operations(self):
        self.monitor.start_monitoring(lambda metrics: GLib.idle_add(self.update_dashboard, metrics), interval=1)

    def stop_backend_operations(self):
        self.monitor.stop_monitoring()

    def get_state(self):
        """Return the current state of the view."""
        # Example: return a dictionary of state data
        return {
            "cpu_label": self.cpu_label.get_text(),
            "memory_label": self.memory_label.get_text(),
            # Add more state data as needed
        }

    def set_state(self, state):
        """Restore the state of the view."""
        if state:
            self.cpu_label.set_text(state.get("cpu_label", "CPU Usage: Loading..."))
            self.memory_label.set_text(state.get("memory_label", "Memory Usage: Loading..."))
            # Restore more state data as needed

