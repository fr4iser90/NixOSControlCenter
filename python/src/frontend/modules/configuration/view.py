from gi.repository import Gtk
from src.frontend.core.theme_manager import ThemeManager

class ConfigurationView(Gtk.Box):
    def __init__(self, root):
        super().__init__(orientation=Gtk.Orientation.VERTICAL)
        
        # Define tab contents
        self.tab_contents = {
            "Overview": {
                "System Info": ["Hostname", "System Version", "Boot Loader", "File Systems"],
                "Hardware": ["CPU/Memory", "Graphics", "Network Devices", "Storage"],
                "Services": ["Running Services", "Enabled Services", "System Units", "User Services"],
                "Quick Actions": ["Update System", "Clean Old Generations", "Rebuild Config", "Show System Status"]
            },
            "Validate & Build": {
                "Editor": ["configuration.nix Editor", "Syntax Highlighting", "Auto-completion", "Common Snippets"],
                "Validation": ["Syntax Check", "Config Validation", "Dependency Check", "Security Audit"],
                "Build": ["Build Status", "Build Logs", "Error Console", "Build Options"],
                "Documentation": ["NixOS Options", "Package Search", "Common Patterns", "Troubleshooting"]
            },
            "Test & Preview": {
                "Changes": ["Config Diff", "Package Changes", "Service Changes", "Impact Analysis"],
                "Test Environment": ["VM Test", "Sandbox Mode", "Test Build", "Resource Usage"],
                "Rollback": ["Previous Configs", "Recovery Options", "Safe Mode", "Emergency Shell"],
                "Verification": ["Service Tests", "Boot Test", "Network Test", "Custom Tests"]
            },
            "History": {
                "Versions": ["Generation List", "Change History", "Comparison Tool", "Restore Points"],
                "Backups": ["Auto Backups", "Manual Backups", "Backup Schedule", "Recovery"],
                "Analytics": ["System Changes", "Update History", "Performance Trends", "Space Usage"],
                "Reports": ["System Reports", "Error Logs", "Update Logs", "Security Alerts"]
            },
            "Import/Export": {
                "Templates": ["Common Configs", "User Templates", "Community Templates", "Template Editor"],
                "Sharing": ["Export Config", "Import Config", "Share Settings", "Collaboration"],
                "Profiles": ["System Profiles", "User Profiles", "Profile Manager", "Profile Switch"],
                "Integration": ["Git Integration", "Cloud Backup", "Remote Sync", "API Access"]
            }
        }
        
        # Create notebook
        self.notebook = Gtk.Notebook()
        self.notebook.set_margin_top(ThemeManager.get_margin())
        self.notebook.set_margin_bottom(ThemeManager.get_margin())
        self.notebook.set_margin_start(ThemeManager.get_margin())
        self.notebook.set_margin_end(ThemeManager.get_margin())
        
        # Create tabs
        for tab_name, panels in self.tab_contents.items():
            tab_content = self._create_tab_content(tab_name, panels)
            tab_label = Gtk.Label(label=tab_name)
            self.notebook.append_page(tab_content, tab_label)
        
        self.append(self.notebook)
    
    def _create_tab_content(self, tab_name, panels):
        # Main container for the tab
        tab_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        
        # Create 2x2 grid for panels
        grid = Gtk.Grid()
        grid.set_row_homogeneous(True)
        grid.set_column_homogeneous(True)
        grid.set_row_spacing(10)
        grid.set_column_spacing(10)
        
        # Create panels based on the configuration
        panel_items = list(panels.items())
        for i, (panel_name, panel_content) in enumerate(panel_items):
            row = i // 2
            col = i % 2
            panel = self._create_panel(panel_name, panel_content)
            grid.attach(panel, col, row, 1, 1)
        
        tab_container.append(grid)
        return tab_container
    
    def _create_panel(self, title, content_items):
        frame = Gtk.Frame()
        ThemeManager.apply_panel_style(frame)
        
        header = Gtk.Label(label=title)
        ThemeManager.apply_header_style(header)
        
        frame.set_margin_start(5)
        frame.set_margin_end(5)
        frame.set_margin_top(5)
        frame.set_margin_bottom(5)
        frame.set_child(header)
        
        # Create content box for the panel
        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        content.set_margin_start(10)
        content.set_margin_end(10)
        content.set_margin_top(10)
        content.set_margin_bottom(10)
        
        # Add content items
        for item in content_items:
            row = self._create_config_row(item, "")
            content.append(row)
        
        frame.set_child(content)
        return frame
    
    def _create_config_row(self, label_text, default_value):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        label = Gtk.Label(label=label_text)
        entry = Gtk.Entry()
        entry.set_text(default_value)
        
        row.append(label)
        row.append(entry)
        return row