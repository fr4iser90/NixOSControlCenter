# Nixify Web Service

REST API Service für Windows/macOS/Linux → NixOS Migration.

## Features

- 📥 Snapshot-Report Upload
- 🔧 Automatische NixOS-Config-Generierung
- 💿 Custom ISO-Builder
- 📊 Session-Management
- 🌐 Moderne Web-UI

## Lokale Entwicklung

```bash
# Dependencies installieren
go mod download

# Service starten
go run main.go

# Oder mit Environment-Variablen
PORT=8080 HOST=0.0.0.0 DATA_DIR=/tmp/nixify go run main.go
```

## Docker Deployment

### Mit Docker Compose (empfohlen)

```bash
# Service bauen und starten
docker-compose up -d

# Logs anzeigen
docker-compose logs -f

# Service stoppen
docker-compose down
```

### Mit Docker direkt

```bash
# Image bauen
docker build -t nixify-web-service .

# Container starten
docker run -d \
  --name nixify-service \
  -p 8080:8080 \
  -v nixify-data:/var/lib/nixify \
  -e PORT=8080 \
  -e HOST=0.0.0.0 \
  nixify-web-service
```

## Environment Variables

- `PORT` - Service Port (default: 8080)
- `HOST` - Bind Address (default: 127.0.0.1, use 0.0.0.0 for all interfaces)
- `DATA_DIR` - Data Directory für Sessions (default: /var/lib/nixify)
- `MAPPING_DB_PATH` - Pfad zur Mapping-Database (optional)

## API Endpoints

- `GET /` - Web-UI Landing Page
- `GET /api/v1/health` - Health Check
- `POST /api/v1/upload` - Upload Snapshot Report
- `GET /api/v1/sessions` - List all Sessions
- `GET /api/v1/session/{id}` - Get Session Details
- `GET /api/v1/config/{id}` - Get Generated Config
- `POST /api/v1/iso/build` - Build Custom ISO
- `GET /api/v1/iso/{id}/download` - Download ISO
- `GET /download/windows` - Download Windows Script
- `GET /download/macos` - Download macOS Script
- `GET /download/linux` - Download Linux Script

## Production Deployment

Für Production auf deinem Server:

1. **Build Image:**
   ```bash
   docker build -t nixify-web-service:latest .
   ```

2. **Push zu Registry (optional):**
   ```bash
   docker tag nixify-web-service:latest your-registry/nixify-web-service:latest
   docker push your-registry/nixify-web-service:latest
   ```

3. **Auf Server deployen:**
   ```bash
   # Mit docker-compose
   docker-compose up -d
   
   # Oder mit docker run
   docker run -d \
     --name nixify-service \
     --restart unless-stopped \
     -p 8080:8080 \
     -v /var/lib/nixify:/var/lib/nixify \
     nixify-web-service:latest
   ```

4. **Reverse Proxy (nginx/Caddy):**
   ```nginx
   server {
       listen 80;
       server_name nixify.yourdomain.com;
       
       location / {
           proxy_pass http://localhost:8080;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```

## Volumes

- `/var/lib/nixify` - Persistente Daten (Sessions, Reports, Configs, ISOs)

## Health Check

```bash
curl http://localhost:8080/api/v1/health
```

## Troubleshooting

- **Port bereits belegt:** Ändere `PORT` Environment Variable
- **Keine Daten-Persistenz:** Stelle sicher, dass Volume gemountet ist
- **Template nicht gefunden:** Template wird via `embed` ins Binary eingebettet, sollte automatisch funktionieren
