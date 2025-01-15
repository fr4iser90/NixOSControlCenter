container-name/
├── config.nix         # Benutzerkonfiguration und Serviceoptionen
├── default.nix        # Einstiegspunkt des Moduls (kombiniert alles)
├── container.nix      # Container-spezifische Logik (Image, Ports, Volumes)
├── vars.nix           # Container-spezifische Umgebungsvariablen
└── README.md          # Dokumentation für den Container
