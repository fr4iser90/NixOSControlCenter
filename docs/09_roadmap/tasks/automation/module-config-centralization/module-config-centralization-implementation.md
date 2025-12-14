# Zentrale ModuleConfig mit dynamischen Namen - Implementation Plan

## 1. Project Overview

- **Feature/Component Name**: Zentrale ModuleConfig mit dynamischen Namen
- **Priority**: High
- **Category**: automation
- **Estimated Time**: 2 hours
- **Dependencies**:
  - Working NixOS flake structure
  - Module discovery system
  - config-helpers.nix mit mkModuleConfig Funktion
- **Related Issues**: Hardcoded module names, Duplikation in moduleConfig
- **Created**: 2025-12-15T00:00:00.000Z

## 2. Technical Requirements

- **Tech Stack**: Nix, NixOS, bash
- **Architecture Pattern**: Zentrale moduleConfig Generierung mit dynamischen Namen aus filesystem
- **Database Changes**: None
- **API Changes**: None
- **Frontend Changes**: None
- **Backend Changes**: NixOS module system refactoring

## 3. File Impact Analysis

### Files to Modify:

- [ ] `nixos/core/management/module-manager/config.nix` - Dynamische Namen in automaticModuleConfigs generieren
- [ ] `nixos/core/management/system-manager/submodules/system-logging/config.nix` - moduleConfig Parameter hinzufügen
- [ ] `nixos/modules/security/ssh-client-manager/default.nix` - Bereits korrekt implementiert (lokale moduleConfig)
- [ ] `nixos/modules/security/ssh-client-manager/config.nix` - Bereits korrekt (verwendet moduleConfig.configPath)
- [ ] `nixos/modules/security/ssh-client-manager/scripts/ssh-client-manager.nix` - Bereits korrekt
- [ ] `nixos/modules/security/ssh-client-manager/handlers/ssh-client-handler.nix` - Bereits korrekt

### Files to Create:

- [ ] None

### Files to Delete:

- [ ] None

## 4. Implementation Phases

### Phase 1: Foundation Setup (30 min)

- [x] Analyse aktuelle moduleConfig Verwendung patterns
- [x] Identifiziere korrekte Lösung: Jedes Modul generiert eigene moduleConfig
- [x] Verstehe mkModuleConfig Funktion aus config-helpers.nix
- [x] Erstelle neue File Impact Analysis

### Phase 2: Core Implementation (60 min)

- [ ] Implementiere dynamische moduleName Generierung in system-update/config.nix
- [ ] Implementiere dynamische cfg in system-logging/config.nix
- [ ] Verifiziere ssh-client-manager als Referenz-Implementierung
- [ ] Teste dass jedes Modul eigene moduleConfig generiert

### Phase 3: Integration (30 min)

- [ ] Führe nixos-rebuild switch test aus
- [ ] Verifiziere dass alle Module korrekt funktionieren
- [ ] Teste dass lokale moduleConfig Überschreibungen funktionieren
- [ ] Dokumentiere Merging Architektur

### Phase 4: Testing & Documentation (15 min)

- [ ] Aktualisiere TODO.md mit finalem Status
- [ ] Dokumentiere dynamische Generierung
- [ ] Erstelle Template für neue Module

### Phase 5: Deployment & Validation (0 min - bereits deployed)

- [ ] Keine zusätzliche Deployment nötig

## 5. Code Standards & Patterns

- **Coding Style**: Nix coding standards, proper indentation, clear comments
- **Naming Conventions**: camelCase for variables, descriptive names
- **Error Handling**: Nix evaluation errors with clear messages
- **Logging**: builtins.trace for debugging, structured output
- **Testing**: Manual testing with nixos-rebuild, automated validation
- **Documentation**: Clear comments explaining dynamic generation

## 6. Security Considerations

- [x] Keine Sicherheitsimplikationen
- [x] Dynamische Namen aus vertrauenswürdigem filesystem
- [x] Bestehende Sicherheit bleibt erhalten

## 7. Performance Requirements

- **Response Time**: N/A - Build-time only
- **Throughput**: N/A - Configuration evaluation
- **Memory Usage**: Minimal impact
- **Database Queries**: None
- **Caching Strategy**: Nix built-in caching

## 8. Testing Strategy

### Unit Tests:

- [ ] Test file: N/A (Nix configuration testing)
- [ ] Test cases: Verify dynamic moduleName generation, cfg resolution
- [ ] Mock requirements: None

### Integration Tests:

- [ ] Test scenarios: nixos-rebuild switch, module loading
- [ ] Test data: Existing NixOS configuration

### E2E Tests:

- [ ] User flows: System boot, module activation
- [ ] Browser compatibility: N/A

### Test Configuration:

- **Backend Tests**: Manual NixOS testing
- **Coverage**: 100% manual verification
- **File Extensions**: .nix testing

## 9. Documentation Requirements

### Code Documentation:

- [ ] Kommentare für dynamische moduleName Generierung
- [ ] Erklärung der Merging Architektur
- [ ] Template für neue Module

### User Documentation:

- [ ] Keine User-Dokumentation nötig

## 10. Deployment Checklist

### Pre-deployment:

- [x] Pattern Analysis durchgeführt
- [x] Reference Implementation identifiziert
- [x] Neue Lösung definiert

### Deployment:

- [ ] nixos-rebuild switch ausführen
- [ ] Alle Module testen

### Post-deployment:

- [ ] System funktioniert korrekt
- [ ] Keine hardcoded Namen mehr

## 11. Rollback Plan

- [ ] Git revert falls nötig
- [ ] Alternative: Hardcoded Namen wiederherstellen
- [ ] Kommunikation: Problem sofort melden

## 12. Success Criteria

- [ ] nixos-rebuild switch erfolgreich
- [ ] Alle Module verwenden dynamische moduleName Generierung
- [ ] Keine hardcoded module names mehr
- [ ] Merging funktioniert (lokale Überschreibungen)
- [ ] ssh-client-manager als Referenz funktioniert

## 13. Risk Assessment

### High Risk:

- [ ] System rebuild schlägt fehl - Mitigation: Git backup bereit

### Medium Risk:

- [ ] baseNameOf funktioniert nicht - Mitigation: Alternative Implementierung

### Low Risk:

- [ ] Performance impact - Mitigation: Minimal

## 14. AI Auto-Implementation Instructions

### AI Execution Context:

```json
{
  "requires_new_chat": false,
  "git_branch_name": "feature/dynamic-module-config",
  "confirmation_keywords": ["fertig", "done", "complete"],
  "fallback_detection": true,
  "max_confirmation_attempts": 3,
  "timeout_seconds": 180
}
```

### Success Indicators:

- [ ] nixos-rebuild switch erfolgreich
- [ ] Alle Module verwenden dynamische Namen
- [ ] Keine hardcoded Namen mehr
- [ ] Merging funktioniert

## 15. References & Resources

- **Technical Documentation**: MODULE_TEMPLATE.md, NixOS module system
- **API References**: baseNameOf, mkModuleConfig, _module.args
- **Design Patterns**: Dynamic configuration generation
- **Best Practices**: DRY principle, filesystem-based naming
- **Similar Implementations**: ssh-client-manager (Referenz-Implementierung)
