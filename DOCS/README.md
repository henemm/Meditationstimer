# DOCS - Documentation Guidelines

**Zweck:** Diese Dokumentation dient Claude Code AI Sessions. Nur das Nötigste!

---

## Namenskonvention

### Prefixes nach Typ:

**`ACTIVE-*.md`** - Temporäre Projektdateien (häufig geändert)
- `ACTIVE-todos.md` - Nur OFFENE Bugs/Tasks (abgeschlossene sofort löschen!)
- `ACTIVE-roadmap.md` - Geplante Features (nach Start → eigene feature-*.md)

**`feature-*.md`** - Feature Spezifikationen
- `feature-workout-timer.md` - Workout Timer Spec
- `feature-smart-reminders.md` - Smart Reminders Spec
- `feature-calendar-goals.md` - Calendar Goals Spec

**`feature-*-testing.md`** - Test-Anweisungen (nach User-Test löschen!)
- `feature-workout-timer-testing.md` - Workout Timer Tests

---

## Regeln

### Was AI wirklich liest:
1. **`/CLAUDE.md`** (Projekt-Root) - IMMER am Anfang
2. **`ACTIVE-todos.md`** - Für aktuelle Bugs/Tasks
3. **`feature-*.md`** - NUR wenn an dem Feature gearbeitet wird

### Was AI NIE liest:
- Detaillierte Architektur-Docs (findet AI via Code-Search)
- Development Guides (redundant)
- Testing Guides (selten relevant)
- Release Notes (User-Facing)

### Datei-Limits:
- **Max 400 Zeilen** pro Datei
- Bei Überschreitung: Split in logische Sub-Themen
- **Max 20 Todos** in ACTIVE-todos.md (sonst priorisieren!)
- **Max 10 Features** in ACTIVE-roadmap.md

### Lösch-Regeln:
- ❌ **Keine Build-Artefakte** (build.log, etc.)
- ❌ **Keine Test-Instructions** nach User-Test
- ❌ **Keine Bug-Analysen** nach Fix (nur in Commit-Message)
- ❌ **Keine "könnte man mal"-Ideen** in Roadmap
- ✅ **Nur aktuelle, relevante Informationen**

### Nach Feature-Implementation:
1. Feature aus `ACTIVE-roadmap.md` löschen
2. `feature-*-testing.md` löschen
3. `feature-*.md` behalten als Referenz (falls Erweiterung)

---

**Letzte Aufräum-Aktion:** 30. Oktober 2025 (27 → 6 Dateien)
