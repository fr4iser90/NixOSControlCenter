from gi.repository import Gtk, Gdk

class ThemeManager:
    """Zentrales Management für alle Design-Aspekte der Anwendung"""
    
    # Farben
    COLORS = {
        "primary": "#0066cc",
        "secondary": "#6c757d",
        "success": "#28a745",
        "warning": "#ffc107",
        "error": "#dc3545",
        "info": "#17a2b8",
        
        "primary-light": "#3385d6",
        "primary-dark": "#004c99",
        
        "background": "#ffffff",
        "surface": "#f8f9fa",
        "surface-alt": "#e9ecef",
        
        "text": "#212529",
        "text-light": "#6c757d",
        "text-dark": "#000000",
        
        "disabled": "#e9ecef",
        "hover": "#e2e6ea",
        "active": "#d3d9df",
        
        "border": "#dee2e6",
        "border-light": "#e9ecef",
        "border-focus": "#80bdff"
    }
    
    # Abstände
    SPACING = {
        "xxs": 2,
        "xs": 4,
        "sm": 8,
        "md": 16,
        "lg": 24,
        "xl": 32,
        "xxl": 48
    }
    
    # Schriften
    FONTS = {
        "h1": "Sans Bold 24",
        "h2": "Sans Bold 20",
        "h3": "Sans Bold 18",
        "header": "Sans Bold 16",
        "subheader": "Sans 14",
        "body": "Sans 12",
        "body-bold": "Sans Bold 12",
        "small": "Sans 10",
        "tiny": "Sans 9",
        "monospace": "Monospace 12"
    }
    
    # Widget Styles
    STYLES = {
        "panel": {
            "margin": 10,
            "padding": 15,
            "border_width": 1,
            "border_radius": 4
        },
        "button": {
            "height": 32,
            "padding": 8,
            "border_radius": 4
        },
        "input": {
            "height": 32,
            "padding": 8,
            "border_radius": 4
        },
        "list": {
            "spacing": 8,
            "padding": 12,
            "min_width": 600,
            "max_width": 1200
        },
        "list_item": {
            "height": 48,
            "padding": 12,
            "spacing": 8
        },
        "button_group": {
            "spacing": 8,
            "min_width": 320,
            "align": "end"
        },
        
        "form": {
            "spacing": 16,
            "label_width": 160,
            "input_width": 240
        },
        
        "card": {
            "padding": 16,
            "margin": 8,
            "border_radius": 8,
            "shadow": "0 2px 4px rgba(0,0,0,0.1)"
        },
        
        "dialog": {
            "width": 480,
            "min_height": 200,
            "padding": 24
        },
        
        "tooltip": {
            "padding": 8,
            "max_width": 300
        },
        
        "nav": {
            "height": 48,
            "padding": 8,
            "item_spacing": 4
        },
        
        "grid": {
            "spacing": 16,
            "padding": 16,
            "columns": 12
        }
    }
    
    @classmethod
    def apply_styles(cls):
        """Lädt und wendet CSS-Styles auf die Anwendung an"""
        css_provider = Gtk.CssProvider()
        css = cls._generate_css()
        css_provider.load_from_data(css.encode())
        
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
    
    @classmethod
    def _generate_css(cls):
        """Generiert CSS aus den definierten Styles"""
        return f"""
            .panel {{
                margin: {cls.SPACING['md']}px;
                padding: {cls.SPACING['md']}px;
                border: {cls.STYLES['panel']['border_width']}px solid {cls.COLORS['border']};
                border-radius: {cls.STYLES['panel']['border_radius']}px;
                background: {cls.COLORS['surface']};
            }}
            
            .header {{
                font: {cls.FONTS['header']};
                color: {cls.COLORS['text']};
            }}
            
            .button {{
                min-height: {cls.STYLES['button']['height']}px;
                padding: {cls.STYLES['button']['padding']}px;
                border-radius: {cls.STYLES['button']['border_radius']}px;
            }}
            
            .metric-label {{
                font: {cls.FONTS['body']};
                color: {cls.COLORS['text']};
                background: {cls.COLORS['surface']};
                padding: {cls.SPACING['sm']}px;
                border-radius: {cls.STYLES['panel']['border_radius']}px;
            }}
            
            .metric-label:hover {{
                background: {cls.COLORS['primary']};
                color: {cls.COLORS['background']};
            }}
            
            .generation-item {{
                background: {cls.COLORS['surface']};
                border: 1px solid {cls.COLORS['border']};
                border-radius: {cls.STYLES['panel']['border_radius']}px;
                padding: {cls.SPACING['sm']}px;
            }}
            
            .current-generation {{
                background: {cls.COLORS['primary']};
                color: {cls.COLORS['background']};
            }}
            
            .edit-button {{
                background: {cls.COLORS['secondary']};
                color: {cls.COLORS['background']};
            }}
            
            .lock-button {{
                background: {cls.COLORS['primary']};
                color: {cls.COLORS['background']};
            }}
            
            .analyze-button {{
                background: {cls.COLORS['secondary']};
                color: {cls.COLORS['background']};
            }}
            
            .delete-button {{
                background: {cls.COLORS['error']};
                color: {cls.COLORS['background']};
            }}
            
            .placeholder-text {{
                color: {cls.COLORS['secondary']};
                font: {cls.FONTS['body']};
                font-style: italic;
            }}
            
            .list-container {{
                min-width: {cls.STYLES['list']['min_width']}px;
                max-width: {cls.STYLES['list']['max_width']}px;
                padding: {cls.STYLES['list']['padding']}px;
                margin: 0 auto;
            }}
            
            .list-item {{
                min-height: {cls.STYLES['list_item']['height']}px;
                padding: {cls.STYLES['list_item']['padding']}px;
                margin-bottom: {cls.STYLES['list']['spacing']}px;
                display: flex;
                align-items: center;
                justify-content: space-between;
            }}
            
            .button-group {{
                display: flex;
                gap: {cls.STYLES['button_group']['spacing']}px;
                min-width: {cls.STYLES['button_group']['min_width']}px;
                justify-content: flex-end;
            }}
            
            /* Responsive Anpassungen */
            @media (max-width: 768px) {{
                .list-item {{
                    flex-direction: column;
                    align-items: stretch;
                    height: auto;
                }}
                
                .button-group {{
                    margin-top: {cls.SPACING['sm']}px;
                    justify-content: center;
                }}
            }}
            
            scrolledwindow {{
                background: {cls.COLORS['background']};
            }}
            
            .list-container {{
                margin: 0;
                padding: {cls.STYLES['list']['padding']}px;
                background: {cls.COLORS['background']};
            }}
            
            .list-item {{
                min-height: {cls.STYLES['list_item']['height']}px;
                padding: {cls.STYLES['list_item']['padding']}px;
                margin-bottom: {cls.STYLES['list']['spacing']}px;
                display: flex;
                align-items: center;
                background: {cls.COLORS['surface']};
            }}
            
            .header {{
                margin: {cls.SPACING['md']}px;
                margin-bottom: {cls.SPACING['lg']}px;
            }}
            
            /* Form Styles */
            .form-container {{
                spacing: {cls.STYLES['form']['spacing']}px;
            }}
            
            .form-label {{
                min-width: {cls.STYLES['form']['label_width']}px;
                color: {cls.COLORS['text']};
            }}
            
            .form-input {{
                min-width: {cls.STYLES['form']['input_width']}px;
            }}
            
            /* Card Styles */
            .card {{
                padding: {cls.STYLES['card']['padding']}px;
                margin: {cls.STYLES['card']['margin']}px;
                border-radius: {cls.STYLES['card']['border_radius']}px;
                box-shadow: {cls.STYLES['card']['shadow']};
                background: {cls.COLORS['surface']};
            }}
            
            /* Status Styles */
            .disabled {{
                opacity: 0.6;
                pointer-events: none;
            }}
            
            .clickable:hover {{
                cursor: pointer;
                background: {cls.COLORS['hover']};
            }}
            
            .selected {{
                background: {cls.COLORS['primary-light']};
                color: {cls.COLORS['background']};
            }}
            
            /* Animation Styles */
            @keyframes fade-in {{
                from {{ opacity: 0; }}
                to {{ opacity: 1; }}
            }}
            
            .animate-fade-in {{
                animation: fade-in 0.3s ease-in-out;
            }}
            
            /* Responsive Grid */
            .grid {{
                display: grid;
                grid-gap: {cls.STYLES['grid']['spacing']}px;
                padding: {cls.STYLES['grid']['padding']}px;
                grid-template-columns: repeat({cls.STYLES['grid']['columns']}, 1fr);
            }}
            
            /* Tooltip */
            .tooltip {{
                padding: {cls.STYLES['tooltip']['padding']}px;
                max-width: {cls.STYLES['tooltip']['max_width']}px;
                background: {cls.COLORS['surface-alt']};
                border-radius: 4px;
                font: {cls.FONTS['small']};
            }}
            
            .generation-label {{
                font: {cls.FONTS['body-bold']};
                color: {cls.COLORS['text']};
                margin-bottom: 2px;
            }}
            
            .generation-details {{
                font: {cls.FONTS['small']};
                color: {cls.COLORS['text-light']};
            }}
            
            .list-item {{
                padding: {cls.SPACING['md']}px;
                border-bottom: 1px solid {cls.COLORS['border-light']};
                background: {cls.COLORS['surface']};
            }}
            
            .list-item:hover {{
                background: {cls.COLORS['hover']};
            }}
            
            .current-generation {{
                background: {cls.COLORS['primary-light']};
            }}
            
            .current-generation:hover {{
                background: {cls.COLORS['primary']};
            }}
        """
    
    @classmethod
    def get_margin(cls, size="md"):
        """Hilfsmethode für konsistente Abstände"""
        return cls.SPACING.get(size, cls.SPACING["md"])
    
    @classmethod
    def apply_panel_style(cls, widget):
        """Wendet Panel-Styling auf ein Widget an"""
        widget.get_style_context().add_class("panel")
    
    @classmethod
    def apply_header_style(cls, widget):
        """Wendet Header-Styling auf ein Widget an"""
        widget.get_style_context().add_class("header")
    
    @classmethod
    def create_list_container(cls):
        """Erstellt einen standardisierten Listen-Container"""
        container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        container.get_style_context().add_class("list-container")
        return container
    
    @classmethod
    def create_list_item(cls):
        """Erstellt ein standardisiertes Listen-Element"""
        item = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        item.get_style_context().add_class("list-item")
        return item
    
    @classmethod
    def create_button_group(cls):
        """Erstellt eine standardisierte Button-Gruppe"""
        group = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        group.get_style_context().add_class("button-group")
        return group
    
    @classmethod
    def create_form_row(cls):
        """Erstellt eine standardisierte Formularzeile"""
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        row.get_style_context().add_class("form-container")
        return row
    
    @classmethod
    def create_card(cls):
        """Erstellt einen Card-Container"""
        card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        card.get_style_context().add_class("card")
        return card
    
    @classmethod
    def create_grid(cls, columns=None):
        """Erstellt einen Grid-Container"""
        grid = Gtk.Grid()
        grid.get_style_context().add_class("grid")
        if columns:
            grid.set_column_homogeneous(True)
            grid.set_column_spacing(cls.STYLES['grid']['spacing'])
        return grid
    
    @classmethod
    def apply_tooltip(cls, widget, text):
        """Fügt einem Widget einen formatierten Tooltip hinzu"""
        tooltip = Gtk.Tooltip()
        tooltip.set_text(text)
        widget.set_tooltip_window(tooltip)
        widget.get_style_context().add_class("tooltip")