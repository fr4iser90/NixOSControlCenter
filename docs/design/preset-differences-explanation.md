# Preset Differences Explanation

## 📋 Preset Overview

### 🖥️ Desktop Preset

**File:** `shell/scripts/setup/modes/presets/desktop.nix`

**What it does:**
- ✅ **Base Desktop System** with GUI
- ✅ **Desktop Environment:** Plasma (default)
- ✅ **Display Manager:** SDDM
- ✅ **Audio:** PipeWire
- ❌ **No Package Features** (empty - just base desktop)
- ❌ **No SSH Server** (client only)
- ❌ **No Services** (no Docker, no databases, etc.)

**Use case:**
- Workstation for daily use
- Development machine (add features via Custom Install)
- Gaming PC (add features via Custom Install)
- Personal computer

**What you get:**
- GUI Desktop Environment
- Base desktop packages (libreoffice, appimage-run, etc.)
- No SSH server
- No containers/services

---

### 🖥️ Server Preset

**File:** `shell/scripts/setup/modes/presets/server.nix`

**What it does:**
- ✅ **Base Server System** (no GUI)
- ✅ **SSH Server** enabled
- ✅ **System Features:** system-logger, system-checks, system-updater, ssh-server-manager
- ❌ **No Desktop Environment** (CLI only)
- ❌ **No Package Features** (empty - just base server)
- ❌ **No Services** (no Docker, no databases, etc.)

**Use case:**
- Minimal server setup
- Base for custom server configuration
- Server where you add features manually
- Production server (add only what you need)

**What you get:**
- Base server packages (iotop, iftop, ufw, nmap, gnupg, etc.)
- SSH server enabled
- No GUI
- No containers/services

---

### 🖥️ Homelab Server Preset

**File:** `nixos/packages/presets/homelab-server.nix`

**What it does:**
- ✅ **Server System** (no GUI)
- ✅ **Package Features:**
  - `docker-rootless` (containerization)
  - `database` (PostgreSQL, MySQL)
  - `web-server` (nginx, apache)
- ✅ **Homelab-ready** (all common services included)
- ❌ **No Desktop Environment** (CLI only)

**Use case:**
- Homelab server
- Self-hosted services
- Container-based services
- Home automation server
- Media server (add features via Custom Install)

**What you get:**
- Base server packages
- Docker (rootless)
- Database servers
- Web server
- Ready for homelab services

---

## 📊 Comparison Table

| Feature | Desktop | Server | Homelab Server |
|---------|---------|--------|----------------|
| **System Type** | `desktop` | `server` | `server` |
| **GUI** | ✅ Yes (Plasma) | ❌ No | ❌ No |
| **SSH Server** | ❌ No | ✅ Yes | ✅ Yes |
| **Docker** | ❌ No | ❌ No | ✅ Yes (rootless) |
| **Database** | ❌ No | ❌ No | ✅ Yes |
| **Web Server** | ❌ No | ❌ No | ✅ Yes |
| **Package Features** | ❌ None | ❌ None | ✅ 3 features |
| **Use Case** | Workstation | Minimal server | Homelab services |

---

## 🎯 When to Use Which?

### Use **Desktop** if:
- You want a GUI
- Personal/workstation computer
- Development machine
- Gaming PC
- You'll add features via Custom Install

### Use **Server** if:
- Minimal server setup
- Production server
- You want to add features manually
- Base server without services
- You need full control over what's installed

### Use **Homelab Server** if:
- Self-hosted services
- Container-based homelab
- You want Docker + Database + Web Server ready
- Home automation
- Media server
- You want services pre-configured

---

## 💡 Key Differences

### Desktop vs Server
- **Desktop:** Has GUI, no SSH server, base desktop packages
- **Server:** No GUI, has SSH server, base server packages

### Server vs Homelab Server
- **Server:** Minimal, no services, just base system
- **Homelab Server:** Pre-configured with Docker, Database, Web Server

### Desktop vs Homelab Server
- **Desktop:** GUI workstation, no services
- **Homelab Server:** CLI server, services included

---

## 🔄 Migration Path

**If you start with Server and want Homelab:**
- Use Custom Install to add: `docker-rootless`, `database`, `web-server`
- Or switch to Homelab Server preset

**If you start with Desktop and want Homelab:**
- Desktop can also host homelab services!
- Use Custom Install to add: `docker-rootless`, `database`, `web-server`
- Or use Homelab Server preset (but you'll lose GUI)

---

## ✅ Summary

**Desktop:**
- GUI + Base desktop packages
- For: Workstation, Gaming, Development

**Server:**
- CLI + SSH + Base server packages
- For: Minimal server, Production, Custom setup

**Homelab Server:**
- CLI + SSH + Docker + Database + Web Server
- For: Self-hosted services, Containers, Home automation

