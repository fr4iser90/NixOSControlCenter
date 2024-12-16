# app/shell/install/preflight/checks/system-information.nix
{ pkgs, lib }:

{
  check = pkgs.writeScriptBin "check-system-info" ''
    #!${pkgs.runtimeShell}
    
    echo "System Information Check"
    echo "----------------------"
    
    # System Info
    echo -e "\nBasic Information:"
    echo "  Hostname: $(${pkgs.hostname}/bin/hostname)"
    echo "  Username: $(${pkgs.coreutils}/bin/whoami)"
    echo "  Shell: $SHELL"
    # User Security Settings
    echo -e "\nUser Security:"
    PASS_STATUS=$(${pkgs.shadow}/bin/passwd -S $(whoami) | cut -d' ' -f2)
    case "$PASS_STATUS" in
      "P") PASS_STATUS="Password Protected" ;;
      "NP") PASS_STATUS="Unprotected" ;;
      "L") PASS_STATUS="Locked" ;;
    esac
    echo "  Security: $PASS_STATUS"
    echo "  Restrictions: ''${ACCOUNT_LOCK:-None}"
    echo -e "\nChecking System Configuration..."
      
    # Versuche über systemctl die aktuelle Konfiguration zu bekommen
    if command -v ${pkgs.systemd}/bin/systemctl >/dev/null; then
      echo "Querying systemd settings:"
      
      # Locale und Keyboard Settings
      echo -e "\nSystem Settings:"
      LOCALE=$(${pkgs.systemd}/bin/localectl status 2>/dev/null)
      if [ ! -z "$LOCALE" ]; then
        echo "$LOCALE" | sed 's/^/  /'
      else
        echo "  Could not get locale settings from systemd"
      fi
    fi
    
    # Current Environment
    echo -e "\nCurrent Environment Settings:"
    echo "Locale Variables:"
    echo "  LANG=$LANG"
    echo "  LC_ALL=$LC_ALL"
    echo "  LANGUAGE=$LANGUAGE"
    
    echo -e "\nDisplay Server:"
    echo "  XDG_SESSION_TYPE=$XDG_SESSION_TYPE"
    if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
      echo "  Running under Wayland"
      if [ -n "$(pidof gnome-shell)" ]; then
        echo "  Desktop: GNOME"
      elif [ -n "$(pidof plasmashell)" ]; then
        echo "  Desktop: KDE Plasma"
      fi
    elif [ -n "$DISPLAY" ]; then
      echo "  Running under X11"
      if command -v ${pkgs.xorg.setxkbmap}/bin/setxkbmap >/dev/null; then
        echo "Current X11 keyboard settings:"
        ${pkgs.xorg.setxkbmap}/bin/setxkbmap -query | sed 's/^/  /'
      fi
    fi
    
    echo -e "\nSystem information check complete."
  '';
}