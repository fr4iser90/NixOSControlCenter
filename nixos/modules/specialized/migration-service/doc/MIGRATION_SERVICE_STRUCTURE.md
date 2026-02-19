# Migration Service - Repository-Struktur Entscheidung

## Die Frage

Soll der Migration-Service ein **Modul im bestehenden Repo** sein oder ein **separates Repository**?

---

## Option 1: Modul im bestehenden Repo ⭐ **EMPFOHLEN**

### Struktur

```
NixOSControlCenter/
├── nixos/
│   └── modules/
│       └── specialized/
│           └── migration-service/        # ← Neues Modul
│               ├── default.nix
│               ├── options.nix
│               ├── config.nix
│               ├── commands.nix
│               ├── snapshot/
│               │   ├── windows/
│               │   │   └── migration-snapshot.ps1
│               │   └── macos/
│               │       └── migration-snapshot.sh
│               ├── mapping/
│               │   └── mapping-database.json
│               ├── web-service/
│               │   ├── api/
│               │   │   └── main.go
│               │   └── config-generator/
│               │       └── generator.nix
│               └── iso-builder/
│                   └── iso-builder.nix
└── migration-service/                   # ← Oder hier im Root?
    └── (gleiche Struktur)
```

### Vorteile

✅ **Nutzt bestehende Module-Infrastruktur**
- Kann `getModuleApi` nutzen
- Integriert sich in CLI-Registry
- Nutzt bestehende Config-Struktur

✅ **Einfachere Integration**
- Gemeinsame Code-Basis
- Keine Code-Duplikation
- Einfacheres Testing

✅ **Konsistente Architektur**
- Folgt MODULE_TEMPLATE
- Einheitliche Patterns
- Einfacheres Onboarding

✅ **Nutzt bestehende Module**
- module-manager API
- system-manager API
- cli-registry für Commands

### Nachteile

⚠️ **Größeres Repo**
- Aber: Modul ist klar getrennt
- Kann optional enabled werden

⚠️ **Könnte komplexer werden**
- Aber: Modulare Struktur hilft

---

## Option 2: Separates Repository

### Struktur

```
NixOSControlCenter/          # Haupt-Repo
└── (bestehende Struktur)

NixOSMigrationService/        # Separates Repo
├── snapshot/
├── mapping/
├── web-service/
└── iso-builder/
```

### Vorteile

✅ **Separation of Concerns**
- Klare Verantwortlichkeiten
- Unabhängige Entwicklung
- Unabhängiges Deployment

✅ **Einfacheres Repo-Management**
- Kleinere Repos
- Klarere Git-History

### Nachteile

❌ **Code-Duplikation**
- Module-APIs müssen nachgebaut werden
- Config-Struktur muss dupliziert werden
- Mehr Wartungsaufwand

❌ **Schwierigere Integration**
- Zwei Repos zu managen
- Versionierung komplexer
- Testing schwieriger

❌ **Nutzt bestehende Module nicht**
- Kann nicht `getModuleApi` nutzen
- Muss alles selbst implementieren

---

## Empfehlung: Modul im bestehenden Repo ⭐

### Warum?

1. **Nutzt bestehende Infrastruktur**
   ```nix
   # migration-service kann direkt nutzen:
   moduleManager = getModuleApi "module-manager";
   systemManager = getModuleApi "system-manager";
   cliRegistry = getModuleApi "cli-registry";
   ```

2. **Folgt etabliertes Pattern**
   - Wie `chronicle` und `ai-workspace`
   - Konsistente Architektur
   - Einfaches Onboarding

3. **Einfachere Entwicklung**
   - Gemeinsame Code-Basis
   - Einfacheres Testing
   - Keine Code-Duplikation

4. **Aber: Web-Service kann separat deployed werden**
   - Modul enthält Web-Service-Code
   - Aber Deployment ist unabhängig
   - Kann auf separatem Server laufen

---

## Konkrete Struktur-Empfehlung

### Als Modul: `modules/specialized/migration-service/`

```
nixos/modules/specialized/migration-service/
├── default.nix                    # Modul-Entry-Point
├── options.nix                    # Config-Optionen
├── config.nix                     # System-Integration
├── commands.nix                   # CLI-Commands (ncc migration-service)
├── README.md
│
├── snapshot/                      # Snapshot-Scripts
│   ├── windows/
│   │   └── migration-snapshot.ps1
│   └── macos/
│       └── migration-snapshot.sh
│
├── mapping/                       # Programm-zu-Modul-Mapping
│   ├── mapping-database.json
│   └── mapper.nix                 # Nix-Mapper-Logic
│
├── web-service/                   # Web-Service (kann separat deployed werden)
│   ├── api/
│   │   ├── main.go
│   │   └── handlers.go
│   ├── config-generator/
│   │   └── generator.nix
│   └── deployment/
│       └── docker-compose.yml     # Optional: Container-Deployment
│
└── iso-builder/                   # ISO-Builder
    └── iso-builder.nix
```

### Integration in CLI

```nix
# commands.nix
(cliRegistry.registerCommandsFor "migration-service" [
  {
    name = "migration-service";
    scope = "module";
    type = "manager";
    description = "Windows/macOS → NixOS Migration Service";
    script = "${migrationServiceScript}/bin/ncc-migration-service";
    category = "specialized";
  }
  {
    name = "snapshot";
    scope = "module";
    parent = "migration-service";
    type = "command";
    description = "Generate system snapshot (Windows/macOS)";
    script = "${snapshotScript}/bin/ncc-migration-snapshot";
  }
])
```

### Web-Service Deployment

**Option A: Als NixOS-Service**
```nix
# config.nix
systemd.services.migration-web-service = {
  enable = cfg.webService.enable;
  serviceConfig.ExecStart = "${webService}/bin/migration-web-service";
};
```

**Option B: Separates Deployment**
- Web-Service-Code im Modul
- Aber: Kann auf separatem Server deployed werden
- Nutzt Docker/Container
- Oder: Separate NixOS-Maschine

---

## Hybrid-Ansatz (Beste von beiden)

### Modul im Repo + Optionales Deployment

```
NixOSControlCenter/
└── nixos/modules/specialized/migration-service/
    ├── (Modul-Code)
    └── web-service/
        ├── api/                    # Web-Service-Code
        └── deployment/             # Deployment-Scripts
            ├── docker-compose.yml  # Container-Deployment
            └── nixos-service.nix   # NixOS-Service (optional)
```

**Vorteile:**
- ✅ Code im Haupt-Repo (nutzt Module)
- ✅ Web-Service kann separat deployed werden
- ✅ Flexible Deployment-Optionen

---

## Finale Empfehlung

### ✅ **Modul im bestehenden Repo**

**Struktur:**
```
nixos/modules/specialized/migration-service/
```

**Gründe:**
1. Nutzt bestehende Module-Infrastruktur
2. Folgt etabliertes Pattern (wie chronicle)
3. Einfacheres Development & Testing
4. Web-Service kann trotzdem separat deployed werden

**Aber:**
- Web-Service-Code ist im Modul
- Deployment kann separat sein (Docker, separate NixOS-Maschine)
- Klare Trennung durch Verzeichnis-Struktur

---

## Migration der aktuellen Struktur

**Aktuell:**
```
migration-service/          # ← Im Root
└── README.md
```

**Ziel:**
```
nixos/modules/specialized/migration-service/
├── default.nix
├── options.nix
├── config.nix
├── commands.nix
├── snapshot/
├── mapping/
├── web-service/
└── iso-builder/
```

**Schritte:**
1. Modul-Struktur erstellen
2. Snapshot-Scripts verschieben
3. Web-Service-Code hinzufügen
4. ISO-Builder integrieren
5. CLI-Commands registrieren

---

## Zusammenfassung

| Aspekt | Modul im Repo | Separates Repo |
|--------|---------------|----------------|
| **Nutzt Module-APIs** | ✅ Ja | ❌ Nein |
| **Code-Duplikation** | ✅ Keine | ❌ Viel |
| **Integration** | ✅ Einfach | ⚠️ Schwer |
| **Deployment** | ✅ Flexibel | ✅ Flexibel |
| **Wartbarkeit** | ✅ Einfach | ⚠️ Komplexer |

**→ Modul im Repo ist die bessere Wahl!** ⭐
