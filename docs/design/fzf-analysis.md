# fzf Analyse: Probleme und Lösungen

## 🔴 PROBLEM 1: Whitespace vor "Advanced Options"

**Wo:** Screen 1 (Installation Type Selection)

**Aktueller Code:**
```bash
INSTALL_TYPE_OPTIONS=(
    "📦 Presets"
    "🔧 Custom Install"
    "⚙️  Advanced Options"  # ← 2 Spaces nach Emoji!
)
```

**Warum Whitespace?**
- `⚙️  Advanced Options` hat **2 Spaces** nach dem Emoji
- fzf zeigt das **exakt so an**, wie es im Array steht
- Keine automatische Whitespace-Entfernung

**Lösung:**
- Entweder: `"⚙️ Advanced Options"` (1 Space)
- Oder: `"⚙️Advanced Options"` (kein Space)

---

## 🔴 PROBLEM 2: Headers sind UNTEN statt OBEN

**Wo:** Screen 2A (Preset Selection), Screen 2B (Custom Install)

**Aktueller Code:**
```bash
preset_list+="🖥️  System Presets\n"
for preset in "${SYSTEM_PRESETS[@]}"; do
    preset_list+="  $preset\n"
done
preset_list+="\n🤖 Device Presets\n"  # ← Header kommt NACH den Items!
```

**Warum unten?**
- fzf zeigt die Liste **in der Reihenfolge** an, wie sie übergeben wird
- Headers werden **NACH** den Items hinzugefügt
- fzf scrollt automatisch → Headers landen unten

**Was fzf KANN:**
- `--header="Text"` → Statischer Header OBEN (nur EINER möglich!)
- `--header-lines=N` → Erste N Zeilen als Header (nicht auswählbar)
- **KEINE** mehreren dynamischen Headers in der Liste

**Was fzf NICHT KANN:**
- Mehrere Headers in der Liste (nur einer mit `--header`)
- Headers automatisch oben halten
- Headers als "nicht auswählbar" markieren (außer `--header-lines`)

---

## 🔴 PROBLEM 3: Headers sind AUSWÄHLBAR

**Wo:** Screen 2A, Screen 2B

**Aktueller Code:**
```bash
preset_list+="🖥️  System Presets\n"  # ← Wird als normale Zeile behandelt!
preset_choice=$(printf "%b" "$preset_list" | fzf ...)
# Filter nach Auswahl:
if [[ "$preset_choice" =~ ^[🖥️🤖] ]]; then
    log_error "Cannot select category header"
fi
```

**Warum auswählbar?**
- Headers sind **normale Zeilen** in der Liste
- fzf behandelt sie wie alle anderen Items
- Filter passiert **NACH** der Auswahl → User kann sie trotzdem auswählen

**Was fzf KANN:**
- `--header-lines=N` → Erste N Zeilen sind Header (nicht auswählbar)
- **ABER:** Nur für die **ersten** N Zeilen!
- **NICHT** für Headers mitten in der Liste

**Was fzf NICHT KANN:**
- Headers mitten in der Liste als "nicht auswählbar" markieren
- Headers automatisch filtern
- Mehrere Header-Bereiche definieren

---

## 📋 fzf FÄHIGKEITEN: Was geht, was nicht?

### ✅ Was fzf KANN:

1. **Statischer Header oben:**
   ```bash
   fzf --header="Select preset"
   ```

2. **Erste N Zeilen als Header (nicht auswählbar):**
   ```bash
   echo -e "Header 1\nHeader 2\nItem 1\nItem 2" | fzf --header-lines=2
   # Header 1 und Header 2 sind NICHT auswählbar
   ```

3. **Preview rechts:**
   ```bash
   fzf --preview="echo {}" --preview-window="right:50%"
   ```

4. **Multi-Select:**
   ```bash
   fzf --multi
   ```

5. **Custom Key Bindings:**
   ```bash
   fzf --bind 'space:accept,ctrl-a:toggle-all'
   ```

### ❌ Was fzf NICHT KANN:

1. **Mehrere Headers in der Liste:**
   - Nur EIN `--header` möglich
   - Keine dynamischen Headers mitten in der Liste

2. **Headers mitten in der Liste als "nicht auswählbar":**
   - `--header-lines` funktioniert nur für die **ersten** N Zeilen
   - Headers mitten drin sind immer auswählbar

3. **Headers automatisch oben halten:**
   - fzf scrollt normal
   - Headers können nach unten rutschen

4. **Whitespace automatisch entfernen:**
   - fzf zeigt exakt an, was übergeben wird
   - Keine automatische Formatierung

---

## 💡 MÖGLICHE LÖSUNGEN (NUR ANALYSE, KEINE IMPLEMENTIERUNG!)

### Lösung 1: Headers mit Präfix markieren
```bash
preset_list+="__HEADER__🖥️  System Presets\n"  # Präfix
for preset in "${SYSTEM_PRESETS[@]}"; do
    preset_list+="$preset\n"  # KEIN Whitespace!
done

# Beim Parsen:
if [[ "$preset_choice" =~ ^__HEADER__ ]]; then
    # Error oder zurück zum Anfang
fi
```

**Vorteile:**
- Headers sind markiert
- Filter funktioniert
- Presets ohne Whitespace

**Nachteile:**
- Präfix ist in fzf sichtbar (könnte stören)
- Headers sind trotzdem auswählbar (Filter erst nach Auswahl)

---

### Lösung 2: Headers mit `--header-lines` (nur für erste Zeilen)
```bash
# Headers ZUERST, dann Items
preset_list="🖥️  System Presets\n"
for preset in "${SYSTEM_PRESETS[@]}"; do
    preset_list+="$preset\n"
done
preset_list+="🤖 Device Presets\n"
for preset in "${DEVICE_PRESETS[@]}"; do
    preset_list+="$preset\n"
done

# Erste 2 Zeilen als Header
fzf --header-lines=2
```

**Vorteile:**
- Headers sind NICHT auswählbar
- Headers bleiben oben

**Nachteile:**
- Funktioniert nur, wenn Headers **ganz oben** sind
- **NICHT** für Headers mitten in der Liste!

---

### Lösung 3: Separator-Zeilen statt Headers
```bash
preset_list+="─────────────────────────\n"
preset_list+="🖥️  System Presets\n"
preset_list+="─────────────────────────\n"
for preset in "${SYSTEM_PRESETS[@]}"; do
    preset_list+="$preset\n"
done
```

**Vorteile:**
- Visuelle Trennung
- Einfach zu implementieren

**Nachteile:**
- Separator ist auswählbar
- Headers sind auswählbar
- Nicht professionell

---

### Lösung 4: Zwei separate fzf-Aufrufe
```bash
# Erst Kategorie wählen
category=$(printf "System Presets\nDevice Presets" | fzf)

# Dann Preset aus Kategorie
if [[ "$category" == "System Presets" ]]; then
    preset=$(printf "%s\n" "${SYSTEM_PRESETS[@]}" | fzf)
fi
```

**Vorteile:**
- Keine Header-Probleme
- Klare Struktur

**Nachteile:**
- Zwei Schritte (User wollte einen Schritt!)
- Nicht wie Custom Install (gruppiert)

---

---

## 🔧 ALLE fzf-OPTIONEN FÜR HEADERS/KATEGORIEN/FORMATIERUNG

### 1. `--header="Text"` / `--header-lines=N`
**Was es macht:**
- `--header="Text"` → Statischer Header oben (nur EINER möglich)
- `--header-lines=N` → Erste N Zeilen als Header (nicht auswählbar)

**Einschränkungen:**
- Nur EIN `--header` möglich
- `--header-lines` nur für die **ersten** N Zeilen
- Headers mitten in Liste sind immer auswählbar

---

### 2. `--delimiter="X"` / `--with-nth=N`
**Was es macht:**
- `--delimiter="|"` → Teilt jede Zeile bei "|"
- `--with-nth=2` → Zeigt nur 2. Feld an (aber filtert nach 1. Feld)

**Beispiel:**
```bash
echo -e "header|System Presets\nitem|Desktop\nitem|Server" | \
  fzf --delimiter="|" --with-nth=2
# Zeigt an: "System Presets", "Desktop", "Server"
# Filtert aber nach: "header", "item", "item"
```

**Für Headers:**
- Headers mit `header|` Präfix → nicht filterbar
- Items mit `item|` Präfix → filterbar
- `--with-nth=2` zeigt nur Text an (ohne Präfix)

**Vorteile:**
- Headers können markiert werden
- Headers sind technisch auswählbar, aber nicht sichtbar

**Nachteile:**
- Komplexere Datenstruktur
- Headers sind trotzdem auswählbar (nur nicht sichtbar)

---

### 3. `--preview` / `--preview-window`
**Was es macht:**
- `--preview="echo {}"` → Zeigt Preview rechts an
- `--preview-window="right:50%"` → Position und Größe

**Für Headers:**
- Headers können in Preview anders dargestellt werden
- Aber: Headers sind trotzdem in Hauptliste auswählbar

**Nicht direkt für Headers, aber für Formatierung**

---

### 4. `--layout=reverse` / `--layout=reverse-list`
**Was es macht:**
- `--layout=reverse` → Liste von unten nach oben
- `--layout=reverse-list` → Liste + Prompt oben

**Für Headers:**
- Headers können oben bleiben (wenn sie zuerst kommen)
- Aber: Headers sind trotzdem auswählbar

**Nicht direkt für Headers, aber für Position**

---

### 5. `--border` / `--border-label`
**Was es macht:**
- `--border` → Rahmen um fzf
- `--border-label="Text"` → Label oben im Rahmen

**Für Headers:**
- Kann als "Header" verwendet werden
- Aber: Nur EIN Label möglich
- Nicht für mehrere Kategorien

---

### 6. `--bind` mit Custom Actions
**Was es macht:**
- `--bind 'enter:execute(...)'` → Custom Action bei Enter
- `--bind 'space:execute(...)'` → Custom Action bei Space

**Für Headers:**
```bash
fzf --bind 'enter:execute(
  if [[ {} =~ ^🖥️ ]]; then
    echo "Header selected" > /dev/tty
    # Zurück zum Anfang
  else
    echo {}
  fi
)'
```

**Vorteile:**
- Headers können abgefangen werden
- Custom Logic möglich

**Nachteile:**
- Komplex
- Headers sind trotzdem auswählbar (nur Custom Action)

---

### 7. `--expect=KEY`
**Was es macht:**
- `--expect=ctrl-a` → Gibt zusätzlich "ctrl-a" aus, wenn gedrückt
- Erste Zeile = Key, zweite Zeile = Selection

**Für Headers:**
- Nicht direkt für Headers
- Aber: Kann für Navigation verwendet werden

---

### 8. `--ansi` / `--color`
**Was es macht:**
- `--ansi` → Interpretiert ANSI Escape Codes
- `--color="..."` → Custom Farben

**Für Headers:**
```bash
echo -e "\033[1;33m🖥️  System Presets\033[0m\nDesktop\nServer" | \
  fzf --ansi
# Headers können farbig sein
```

**Vorteile:**
- Headers visuell unterscheidbar
- Einfach zu implementieren

**Nachteile:**
- Headers sind trotzdem auswählbar
- Nur visuelle Unterscheidung

---

### 9. `--format="..."` / `--print-query`
**Was es macht:**
- `--format="{}"` → Custom Output-Format
- `--print-query` → Gibt auch Query aus

**Für Headers:**
- Nicht direkt für Headers
- Aber: Kann Output formatieren

---

### 10. `--height` / `--min-height`
**Was es macht:**
- `--height=50%` → Höhe in Prozent
- `--min-height=10` → Minimale Höhe

**Für Headers:**
- Nicht direkt für Headers
- Aber: Kann Layout beeinflussen

---

## 🎯 ZUSAMMENFASSUNG: Welche Optionen helfen bei Headers?

### ✅ Direkt für Headers:
1. **`--header="Text"`** → Statischer Header oben (nur EINER)
2. **`--header-lines=N`** → Erste N Zeilen als Header (nur erste Zeilen!)

### ⚠️ Indirekt für Headers:
3. **`--delimiter` + `--with-nth`** → Headers mit Präfix, nur Text anzeigen
4. **`--ansi` + Farben** → Headers visuell unterscheidbar (aber auswählbar)
5. **`--bind` + Custom Actions** → Headers abfangen bei Enter

### ❌ Nicht für Headers:
6. **`--preview`** → Nur für Preview, nicht für Headers
7. **`--layout`** → Nur für Position, nicht für Headers
8. **`--border-label`** → Nur EIN Label, nicht mehrere
9. **`--format`** → Nur für Output, nicht für Headers
10. **`--height`** → Nur für Größe, nicht für Headers

---

## 🎯 FAZIT: Was ist das Problem?

1. **Whitespace:** Einfach zu fixen → Array korrigieren
2. **Headers unten:** fzf zeigt Liste in Reihenfolge → Headers müssen OBEN sein
3. **Headers auswählbar:** fzf kann Headers mitten in Liste NICHT als "nicht auswählbar" markieren

**Die einzige echte Lösung für nicht-auswählbare Headers:**
- `--header-lines=N` (nur für erste N Zeilen!)
- Oder: Headers mit Präfix + Filter nach Auswahl (User kann sie trotzdem auswählen, aber Error danach)
- Oder: `--delimiter` + `--with-nth` (Headers technisch auswählbar, aber nicht sichtbar)

