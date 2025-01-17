{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  trackerApp = pkgs.stdenv.mkDerivation {
    name = "tracker-app";
    src = ./.;
    buildInputs = with pkgs; [
      python3
      python3Packages.pygobject3
      python3Packages.pyyaml
      python3Packages.pycairo
      python3Packages.gst-python
      gtk3
      gobject-introspection
      librsvg
      makeWrapper
    ];
    installPhase = ''
      if [ ! -f ${./tracker_ui.py} ]; then
        echo "Error: tracker_ui.py not found in source directory!"
        exit 1
      fi
      
      mkdir -p $out/bin
      cp ${./tracker_ui.py} $out/bin/tracker_ui.py
      chmod 755 $out/bin/tracker_ui.py
      
      wrapProgram $out/bin/tracker_ui.py \
        --set PYTHONPATH ${pkgs.python3Packages.pygobject3}/${pkgs.python3.sitePackages}:${pkgs.python3Packages.pycairo}/${pkgs.python3.sitePackages} \
        --set GI_TYPELIB_PATH ${pkgs.gtk3}/lib/girepository-1.0 \
        --set GDK_PIXBUF_MODULE_FILE ${pkgs.librsvg.out}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache
    '';
  };
in {
  options.features.tracker = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable the multi-roadmap tracker";
    };
    
    interval = mkOption {
      type = types.str;
      default = "5m";
      description = "How often to check roadmaps";
    };
  };

  config = {
    environment.systemPackages = with pkgs; [
      (pkgs.writeShellScriptBin "multi-roadmap-tracker" ''
        ${pkgs.python3}/bin/python ${trackerApp}/bin/tracker_ui.py
      '')
      libnotify
      dunst
      papirus-icon-theme
      gtk3
      gobject-introspection
    ];

    # Create config directory and copy example roadmap
    system.activationScripts.setupTrackerConfig = ''
      mkdir -p $HOME/.config/multi-roadmap-tracker
      if [ ! -f $HOME/.config/multi-roadmap-tracker/roadmaps.json ]; then
        cp ${./example-roadmap.json} $HOME/.config/multi-roadmap-tracker/roadmaps.json
        chmod 600 $HOME/.config/multi-roadmap-tracker/roadmaps.json
      fi
    '';

    # Desktop entry
    environment.etc."xdg/autostart/multi-roadmap-tracker.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=Multi-Roadmap Tracker
      Exec=multi-roadmap-tracker
      Icon=task-due
      Categories=Utility;
    '';
  };
}
