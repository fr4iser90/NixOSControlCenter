{ pkgs }:

pkgs.writeShellScriptBin "scan-desktop" ''
  #!${pkgs.bash}/bin/bash
  set -euo pipefail
  
  OUTPUT_FILE="$1"
  
  echo "🖥️  Scanning desktop settings..."
  
  # Detect desktop environment
  DESKTOP_ENV=""
  if [ -n "$XDG_CURRENT_DESKTOP" ]; then
    DESKTOP_ENV="$XDG_CURRENT_DESKTOP"
  elif [ -n "$DESKTOP_SESSION" ]; then
    DESKTOP_ENV="$DESKTOP_SESSION"
  else
    DESKTOP_ENV="unknown"
  fi
  
  # Detect display server
  DISPLAY_SERVER=""
  if [ -n "$WAYLAND_DISPLAY" ]; then
    DISPLAY_SERVER="wayland"
  elif [ -n "$DISPLAY" ]; then
    DISPLAY_SERVER="x11"
  else
    DISPLAY_SERVER="unknown"
  fi
  
  # Detect dark mode (various methods depending on DE)
  DARK_MODE="false"
  if command -v gsettings >/dev/null 2>&1; then
    # GNOME/GTK
    if gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | grep -q dark; then
      DARK_MODE="true"
    elif gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | grep -qi dark; then
      DARK_MODE="true"
    fi
  elif [ -f "$HOME/.config/kdeglobals" ]; then
    # KDE/Plasma
    if grep -q "ColorScheme=.*Dark" "$HOME/.config/kdeglobals" 2>/dev/null; then
      DARK_MODE="true"
    fi
  elif [ -f "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" ]; then
    # XFCE
    if grep -qi "dark" "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml" 2>/dev/null; then
      DARK_MODE="true"
    fi
  fi
  
  # Detect cursor theme
  CURSOR_THEME=""
  if command -v gsettings >/dev/null 2>&1; then
    CURSOR_THEME=$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'" || echo "")
  elif [ -f "$HOME/.config/kdeglobals" ]; then
    CURSOR_THEME=$(grep "cursorTheme=" "$HOME/.config/kdeglobals" 2>/dev/null | cut -d'=' -f2 || echo "")
  fi
  
  # Detect icon theme
  ICON_THEME=""
  if command -v gsettings >/dev/null 2>&1; then
    ICON_THEME=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | tr -d "'" || echo "")
  elif [ -f "$HOME/.config/kdeglobals" ]; then
    ICON_THEME=$(grep "Theme=" "$HOME/.config/kdeglobals" 2>/dev/null | head -1 | cut -d'=' -f2 || echo "")
  fi
  
  # Detect GTK theme
  GTK_THEME=""
  if command -v gsettings >/dev/null 2>&1; then
    GTK_THEME=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'" || echo "")
  elif [ -f "$HOME/.config/gtk-3.0/settings.ini" ]; then
    GTK_THEME=$(grep "gtk-theme-name=" "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null | cut -d'=' -f2 || echo "")
  fi
  
  # Detect font settings
  FONT_NAME=""
  FONT_SIZE=""
  if command -v gsettings >/dev/null 2>&1; then
    FONT_NAME=$(gsettings get org.gnome.desktop.interface font-name 2>/dev/null | tr -d "'" | cut -d' ' -f1 || echo "")
    FONT_SIZE=$(gsettings get org.gnome.desktop.interface font-name 2>/dev/null | tr -d "'" | cut -d' ' -f2 || echo "")
  fi
  
  # Detect wallpaper
  WALLPAPER=""
  if command -v gsettings >/dev/null 2>&1; then
    WALLPAPER=$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null | tr -d "'" || echo "")
  elif [ -f "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" ]; then
    WALLPAPER=$(grep "Image=" "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" 2>/dev/null | head -1 | cut -d'=' -f2 || echo "")
  fi
  
  # Detect audio system
  AUDIO_SYSTEM=""
  if systemctl is-active --quiet pipewire.service 2>/dev/null; then
    AUDIO_SYSTEM="pipewire"
  elif systemctl is-active --quiet pulseaudio.service 2>/dev/null; then
    AUDIO_SYSTEM="pulseaudio"
  elif systemctl is-active --quiet alsa.service 2>/dev/null; then
    AUDIO_SYSTEM="alsa"
  fi
  
  # Create JSON output
  ${pkgs.jq}/bin/jq -n \
    --arg env "$DESKTOP_ENV" \
    --arg server "$DISPLAY_SERVER" \
    --argjson dark "$(echo "$DARK_MODE" | ${pkgs.jq}/bin/jq -R 'if . == "true" then true else false end')" \
    --arg cursor "$CURSOR_THEME" \
    --arg icon "$ICON_THEME" \
    --arg gtk "$GTK_THEME" \
    --arg font "$FONT_NAME" \
    --arg fontSize "$FONT_SIZE" \
    --arg wallpaper "$WALLPAPER" \
    --arg audio "$AUDIO_SYSTEM" \
    '{
      desktop: {
        environment: $env,
        displayServer: $server,
        theme: {
          dark: $dark,
          cursor: $cursor,
          icon: $icon,
          gtk: $gtk,
          font: {
            name: $font,
            size: $fontSize
          },
          wallpaper: $wallpaper
        },
        audio: $audio
      }
    }' > "$OUTPUT_FILE"
  
  echo "✅ Desktop settings scanned"
''

