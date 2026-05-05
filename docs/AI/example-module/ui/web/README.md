# Web-Interface (optional)

## Purpose
Web-Service mit REST API (wie nixify)

## Struktur
```
web/
├── api/          # REST API Backend (Go)
│   ├── main.go   # Go API Server
│   ├── handlers/ # API Handlers
│   └── templates/# HTML Templates
├── frontend/     # Frontend (optional)
└── docker/       # Docker für Web-Service
```

## Verwendung

```nix
# In config.nix
let
  webService = buildGoApplication {
    pname = "example-web-service";
    src = ./ui/web/api;
    # ...
  };
in
{
  systemd.services.example-web-service = {
    enable = true;
    serviceConfig.ExecStart = "${webService}/bin/example-web-service";
  };
}
```

## Beispiel
```bash
# Web-Service starten
systemctl start example-web-service
# → API verfügbar auf http://localhost:8080
```
