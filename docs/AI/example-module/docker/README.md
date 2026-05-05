# Docker-Konfiguration

## Purpose
Docker-Compose und Dockerfiles (aus Root verschoben)

## Struktur
```
docker/
├── docker-compose.yml          # Haupt-Compose
├── docker-compose.traefik.yml  # Traefik-spezifisch
└── Dockerfile                  # Falls nötig
```

## Wichtig
- **Nicht im Modul-Root**: Docker-Compose in `docker/` oder `ui/web/docker/`
- **Web-Service**: Wenn nur für Web-Service → `ui/web/docker/`
- **Allgemein**: Wenn für gesamtes Modul → `docker/`

## Beispiel
```bash
# Docker-Compose starten
cd docker
docker-compose up -d
```
