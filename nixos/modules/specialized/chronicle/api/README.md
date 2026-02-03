# 🌐 NixOS Step Recorder - REST API Documentation

**Version:** 2.0.0  
**API Type:** REST (FastAPI)  
**Authentication:** JWT Tokens + API Keys  
**Format:** JSON

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Authentication](#authentication)
4. [API Endpoints](#api-endpoints)
5. [Webhooks](#webhooks)
6. [Configuration](#configuration)
7. [Examples](#examples)

---

## 🎯 Overview

The Step Recorder REST API provides programmatic access to recording sessions, allowing:

- **Remote Control**: Start/stop recordings via HTTP
- **Session Management**: List, query, and delete sessions
- **Export Automation**: Trigger exports in various formats
- **Webhook Integration**: Receive real-time event notifications
- **Multi-Client Support**: Control from web apps, scripts, or CI/CD

### Features

✅ Full CRUD operations on sessions  
✅ JWT + API Key authentication  
✅ OpenAPI/Swagger documentation  
✅ Webhook support for events  
✅ CORS enabled  
✅ Async/background processing  
✅ Nix-integrated (pure Nix configuration)

---

## 🚀 Quick Start

### 1. Enable API in NixOS Configuration

```nix
{
  systemConfig.modules.specialized.chronicle = {
    enable = true;
    
    # Enable REST API
    api = {
      enable = true;
      host = "127.0.0.1";  # Use "0.0.0.0" for external access
      port = 8000;
      autoStart = true;  # Start as systemd service
    };
  };
}
```

### 2. Rebuild NixOS

```bash
sudo nixos-rebuild switch
```

### 3. Start API Server

```bash
# Manual start
chronicle-api

# Or use systemd (if autoStart = true)
systemctl --user start chronicle-api
systemctl --user status chronicle-api
```

### 4. Access API Documentation

Open in browser:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **OpenAPI JSON**: http://localhost:8000/openapi.json

### 5. Get Authentication Token

```bash
# Get JWT token
TOKEN=$(chronicle-api-client auth)
echo $TOKEN

# Or using curl
TOKEN=$(curl -s -X POST http://localhost:8000/auth/token | jq -r '.access_token')
export CHRONICLE_API_TOKEN=$TOKEN
```

---

## 🔐 Authentication

The API supports two authentication methods:

### 1. JWT Tokens (Temporary)

**Pros**: Short-lived, secure for interactive use  
**Cons**: Expires after 60 minutes (configurable)

```bash
# Get token
curl -X POST http://localhost:8000/auth/token

# Response
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer",
  "expires_in": 3600
}

# Use token
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/sessions
```

### 2. API Keys (Permanent)

**Pros**: Long-lived, ideal for automation/CI  
**Cons**: Must be stored securely

```bash
# Create API key (requires existing token)
curl -X POST http://localhost:8000/auth/api-keys \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "CI Pipeline", "expires_days": 365}'

# Response
{
  "key": "m7_xK9vRsT2pL4nQ8yH6wZ...",
  "name": "CI Pipeline",
  "created_at": "2026-01-02T15:00:00",
  "expires_at": "2027-01-02T15:00:00"
}

# Use API key
export API_KEY="m7_xK9vRsT2pL4nQ8yH6wZ..."
curl -H "Authorization: Bearer $API_KEY" http://localhost:8000/sessions
```

---

## 📡 API Endpoints

### Health & Info

#### `GET /` - API Root
```bash
curl http://localhost:8000/
```

#### `GET /health` - Health Check
```bash
curl http://localhost:8000/health
```

#### `GET /stats` - Statistics (auth required)
```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/stats
```

### Sessions

#### `GET /sessions` - List Sessions
```bash
# List all sessions
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/sessions

# Filter by status
curl -H "Authorization: Bearer $TOKEN" \
  "http://localhost:8000/sessions?status=active&limit=10"
```

#### `GET /sessions/{session_id}` - Get Session Details
```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/sessions/session_20260102_150000
```

#### `DELETE /sessions/{session_id}` - Delete Session
```bash
curl -X DELETE \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/sessions/session_20260102_150000
```

### Steps

#### `GET /sessions/{session_id}/steps` - List Steps
```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/sessions/session_20260102_150000/steps
```

#### `GET /sessions/{session_id}/steps/{step_number}/screenshot` - Get Screenshot
```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/sessions/session_20260102_150000/steps/5/screenshot \
  --output screenshot_5.jpg
```

### Recording Control

#### `POST /recording` - Control Recording
```bash
# Start recording
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action": "start", "title": "Bug Report", "description": "Testing API"}' \
  http://localhost:8000/recording

# Stop recording
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action": "stop"}' \
  http://localhost:8000/recording

# Pause/Resume
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action": "pause"}' \
  http://localhost:8000/recording
```

#### `POST /recording/capture` - Capture Step
```bash
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/recording/capture
```

### Export

#### `POST /export` - Export Session
```bash
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "session_id": "session_20260102_150000",
    "format": "html"
  }' \
  http://localhost:8000/export
```

#### `GET /export/{session_id}/{format}` - Download Export
```bash
# Download HTML report
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/export/session_20260102_150000/html \
  --output report.html

# Download PDF
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/export/session_20260102_150000/pdf \
  --output report.pdf
```

### Webhooks

#### `POST /webhooks` - Register Webhook
```bash
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://hooks.example.com/chronicle",
    "events": ["session.started", "session.stopped", "export.completed"],
    "secret": "my-webhook-secret",
    "enabled": true
  }' \
  http://localhost:8000/webhooks
```

#### `GET /webhooks` - List Webhooks
```bash
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/webhooks
```

#### `DELETE /webhooks/{index}` - Delete Webhook
```bash
curl -X DELETE \
  -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/webhooks/0
```

---

## 🪝 Webhooks

Webhooks allow you to receive real-time notifications when events occur.

### Supported Events

- `session.started` - Recording started
- `session.stopped` - Recording stopped
- `session.deleted` - Session deleted
- `step.captured` - Step captured
- `export.completed` - Export finished

### Webhook Payload

```json
{
  "event": "session.started",
  "timestamp": "2026-01-02T15:00:00",
  "data": {
    "session_id": "session_20260102_150000",
    "title": "Bug Report"
  },
  "signature": "sha256_hmac_signature"
}
```

### Verifying Webhook Signatures

```python
import hmac
import hashlib
import json

def verify_webhook(payload, signature, secret):
    expected = hmac.new(
        secret.encode(),
        json.dumps(payload).encode(),
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(signature, expected)
```

---

## ⚙️ Configuration

### NixOS Module Options

```nix
systemConfig.modules.specialized.chronicle.api = {
  enable = true;               # Enable API
  host = "127.0.0.1";          # Bind address
  port = 8000;                 # Port
  tokenExpireMinutes = 60;     # JWT expiration
  corsOrigins = ["*"];         # CORS origins
  enableAuth = true;           # Enable authentication
  enableWebhooks = true;       # Enable webhooks
  autoStart = false;           # Auto-start via systemd
};
```

### Environment Variables

```bash
# API Configuration
export CHRONICLE_API_HOST="0.0.0.0"
export CHRONICLE_API_PORT="8000"
export CHRONICLE_API_SECRET="your-secret-key"
export CHRONICLE_DATA_DIR="/path/to/recordings"

# Client Configuration
export CHRONICLE_API_URL="http://localhost:8000"
export CHRONICLE_API_TOKEN="your-token"
```

---

## 💡 Examples

### Example 1: Automated Recording in CI/CD

```bash
#!/usr/bin/env bash
# Start recording at beginning of test
SESSION=$(curl -s -X POST \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action": "start", "title": "CI Test Run"}' \
  http://api.example.com:8000/recording | jq -r '.session_id')

# Run your tests
./run-tests.sh

# Stop recording and export
curl -s -X POST \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"action": "stop"}' \
  http://api.example.com:8000/recording

# Export to HTML
curl -s -X POST \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"session_id\": \"$SESSION\", \"format\": \"html\"}" \
  http://api.example.com:8000/export
```

### Example 2: Python Client

```python
import requests

class StepRecorderAPI:
    def __init__(self, base_url, token):
        self.base_url = base_url
        self.headers = {"Authorization": f"Bearer {token}"}
    
    def start_recording(self, title=None):
        response = requests.post(
            f"{self.base_url}/recording",
            json={"action": "start", "title": title},
            headers=self.headers
        )
        return response.json()
    
    def stop_recording(self):
        response = requests.post(
            f"{self.base_url}/recording",
            json={"action": "stop"},
            headers=self.headers
        )
        return response.json()
    
    def list_sessions(self):
        response = requests.get(
            f"{self.base_url}/sessions",
            headers=self.headers
        )
        return response.json()

# Usage
api = StepRecorderAPI("http://localhost:8000", "your-token")
api.start_recording("My Test Session")
# ... do work ...
api.stop_recording()
```

### Example 3: JavaScript/TypeScript Client

```typescript
class StepRecorderAPI {
  constructor(
    private baseUrl: string,
    private token: string
  ) {}

  async startRecording(title?: string) {
    const response = await fetch(`${this.baseUrl}/recording`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${this.token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ action: 'start', title }),
    });
    return response.json();
  }

  async getSessions() {
    const response = await fetch(`${this.baseUrl}/sessions`, {
      headers: {
        'Authorization': `Bearer ${this.token}`,
      },
    });
    return response.json();
  }
}

// Usage
const api = new StepRecorderAPI('http://localhost:8000', 'your-token');
await api.startRecording('Browser Test');
```

---

## 🔒 Security Best Practices

1. **Use HTTPS** in production (configure reverse proxy)
2. **Restrict CORS origins** to known domains only
3. **Store API keys securely** (environment variables, secrets manager)
4. **Rotate API keys** regularly
5. **Use specific permissions** (future: role-based access)
6. **Monitor API usage** via logs and metrics
7. **Rate limiting** (configure via reverse proxy)

---

## 🐛 Troubleshooting

### API server won't start

```bash
# Check if port is in use
ss -tlnp | grep 8000

# Check systemd logs
journalctl --user -u chronicle-api -f

# Test manually
chronicle-api
```

### Authentication fails

```bash
# Verify token
echo $CHRONICLE_API_TOKEN

# Get new token
TOKEN=$(chronicle-api-client auth)
```

### Webhook not triggering

```bash
# Check webhook configuration
chronicle-api-client webhooks

# Check API logs for errors
journalctl --user -u chronicle-api | grep webhook
```

---

## 📚 Additional Resources

- **OpenAPI Spec**: http://localhost:8000/openapi.json
- **Interactive Docs**: http://localhost:8000/docs
- **Alternative Docs**: http://localhost:8000/redoc
- **Source Code**: `nixos/modules/specialized/chronicle/api/`

---

## 🤝 Contributing

For API improvements or bug reports, please see the main project documentation.

---

**Version**: 2.0.0  
**Last Updated**: January 2, 2026  
**License**: Same as NixOS Step Recorder project
