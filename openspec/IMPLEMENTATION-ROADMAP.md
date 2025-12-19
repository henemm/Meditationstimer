# Implementation Roadmap - Healthy Habits Haven

## Overview

Priorisierte Reihenfolge für die Umsetzung der "Healthy Habits Haven" Features. Basierend auf Abhängigkeiten und Wertschöpfung.

---

## Phase 1: Foundation (Grundlage)

**Ziel:** Neue App-Struktur ohne Funktionsverlust

### 1.1 Tab-Navigation Refactoring
**Priorität:** KRITISCH (Blocker für alles andere)

| Task | Beschreibung | Spec |
|------|--------------|------|
| Tab-Bar → 4 Tabs | Meditation, Workout, Tracker, Erfolge | `app-navigation.md` |
| Meditation Tab | Offen + Atem kombinieren (Scrolling) | `app-navigation.md` |
| Workout Tab | Frei + Programme kombinieren (Scrolling) | `app-navigation.md` |
| Erfolge Tab | Kalender umbenennen + Header anpassen | `app-navigation.md` |
| Tab Order Setting | Drag & Drop in Settings | `settings.md` |

**Risiko:** Gering - nur UI-Umstrukturierung, keine Logik-Änderung
**Geschätzte Komplexität:** Mittel

### 1.2 SwiftData Tracker Model
**Priorität:** KRITISCH (Basis für alle Tracker-Features)

| Task | Beschreibung | Spec |
|------|--------------|------|
| `Tracker` Model | id, name, icon, type, mode, settings | `trackers.md` |
| `TrackerLog` Model | id, trackerId, timestamp, value, note | `trackers.md` |
| Predefined Presets | Stimmung, Gefühle, Dankbarkeit, Wasser + Saboteure | `trackers.md` |
| Migration | Bestehende Daten erhalten | - |

**Risiko:** Mittel - neues Datenmodell
**Geschätzte Komplexität:** Mittel

---

## Phase 2: Core Tracker (Kernfunktion)

**Ziel:** Tracker-Tab funktionsfähig

### 2.1 Tracker Tab UI
**Priorität:** HOCH

| Task | Beschreibung | Spec |
|------|--------------|------|
| NoAlc Section | Bestehende UI in Tab integrieren (prominent oben) | `app-navigation.md` |
| Good Trackers List | Counter + Selection Types | `trackers.md` |
| Saboteur Trackers List | Awareness Mode UI | `trackers.md` |
| Quick-Log Buttons | Tap → Log → Feedback | `trackers.md` |
| Add Tracker Sheet | Neuen Tracker erstellen | `trackers.md` |

**Abhängigkeit:** Phase 1.1 + 1.2
**Geschätzte Komplexität:** Hoch

### 2.2 Tracker Logging
**Priorität:** HOCH

| Task | Beschreibung | Spec |
|------|--------------|------|
| Selection UI | Emoji-Auswahl für Stimmung/Gefühle | `trackers.md` |
| Counter UI | +/- Buttons für Wasser | `trackers.md` |
| Note Entry | Optional bei Dankbarkeit | `trackers.md` |
| HealthKit Sync | Stimmung → HKStateOfMind, Wasser → dietaryWater | `trackers.md` |

**Abhängigkeit:** Phase 2.1
**Geschätzte Komplexität:** Mittel

---

## Phase 3: Motivation & Visualisierung

**Ziel:** Erfolge-Tab vollständig, Motivation sichtbar

### 3.1 Erfolge Tab Header
**Priorität:** MITTEL

| Task | Beschreibung | Spec |
|------|--------------|------|
| Streak Header | 🧘 🏋️ 🍀 + Custom Tracker Streaks | `streaks-rewards.md` |
| Rewards Display | ⭐ Anzahl prominent | `streaks-rewards.md` |
| Expandable Section | Alle Tracker-Streaks (wenn viele) | `streaks-rewards.md` |

**Abhängigkeit:** Phase 1.2
**Geschätzte Komplexität:** Gering

### 3.2 Focus Tracker in Calendar
**Priorität:** MITTEL

| Task | Beschreibung | Spec |
|------|--------------|------|
| Focus Tracker Config | Max 2 auswählen in Settings | `calendar-view.md` |
| Calendar Center Segments | 1-2 Segmente im Zentrum | `calendar-view.md` |
| Day Detail + Tracker | Tracker-Logs in Day Sheet | `calendar-view.md` |

**Abhängigkeit:** Phase 1.2 + 2.2
**Geschätzte Komplexität:** Mittel

### 3.3 Tracker Streaks
**Priorität:** MITTEL

| Task | Beschreibung | Spec |
|------|--------------|------|
| Awareness Streak Logic | Consecutive days of reflection | `streaks-rewards.md` |
| Avoidance Streak Logic | Consecutive days WITHOUT log | `streaks-rewards.md` |
| Streak per Tracker | Optional, konfigurierbar | `streaks-rewards.md` |

**Abhängigkeit:** Phase 1.2
**Geschätzte Komplexität:** Mittel

---

## Phase 4: Quick Access (Widget & Reminders)

**Ziel:** Logging außerhalb der App

### 4.1 Tracker Widget
**Priorität:** MITTEL-HOCH

| Task | Beschreibung | Spec |
|------|--------------|------|
| Small Widget | 2 Tracker | `tracker-widget.md` |
| Medium Widget | 4 Tracker | `tracker-widget.md` |
| Large Widget | 6 Tracker + Header | `tracker-widget.md` |
| Lock Screen Widget | 1 Tracker (compact) | `tracker-widget.md` |
| Interactive Buttons | App Intent für direktes Logging | `tracker-widget.md` |
| Widget Config | Welche Tracker anzeigen | `tracker-widget.md` |

**Abhängigkeit:** Phase 1.2 + 2.2
**Geschätzte Komplexität:** Hoch (WidgetKit + App Intents)

### 4.2 Smart Reminders für Tracker
**Priorität:** MITTEL

| Task | Beschreibung | Spec |
|------|--------------|------|
| Tracker Reminder Type | In SmartReminderEngine | `smart-reminders.md` |
| SwiftData Check | TrackerLog statt HealthKit | `smart-reminders.md` |
| Notification Actions | Emoji-Buttons für Selection | `smart-reminders.md` |
| Widget Cancellation | Widget-Log cancelt Reminder | `smart-reminders.md` |

**Abhängigkeit:** Phase 1.2 + 4.1
**Geschätzte Komplexität:** Mittel

---

## Phase 5: Polish & Refinement

**Ziel:** Feinschliff und Kantenglättung

### 5.1 Control Center Widget (iOS 18+)
**Priorität:** NIEDRIG

| Task | Beschreibung | Spec |
|------|--------------|------|
| ControlWidget | Quick-Log aus Control Center | `tracker-widget.md` |

**Abhängigkeit:** Phase 4.1
**Geschätzte Komplexität:** Gering

### 5.2 Saboteur Mode Switch
**Priorität:** NIEDRIG

| Task | Beschreibung | Spec |
|------|--------------|------|
| Awareness → Avoidance | Mit Streak-Archivierung | `trackers.md` |
| Warning UI | "Awareness Streak wird archiviert" | `trackers.md` |

**Abhängigkeit:** Phase 2.1 + 3.3
**Geschätzte Komplexität:** Gering

---

## Dependency Graph

```
Phase 1.1 (Tab Navigation)
    │
    ├──→ Phase 1.2 (SwiftData Model)
    │        │
    │        ├──→ Phase 2.1 (Tracker Tab UI)
    │        │        │
    │        │        └──→ Phase 2.2 (Tracker Logging)
    │        │                 │
    │        │                 ├──→ Phase 3.2 (Focus Tracker Calendar)
    │        │                 │
    │        │                 └──→ Phase 4.1 (Widget)
    │        │                          │
    │        │                          └──→ Phase 4.2 (Smart Reminders)
    │        │                                   │
    │        │                                   └──→ Phase 5.1 (Control Center)
    │        │
    │        ├──→ Phase 3.1 (Erfolge Header)
    │        │
    │        └──→ Phase 3.3 (Tracker Streaks)
    │                 │
    │                 └──→ Phase 5.2 (Mode Switch)
    │
    └──→ (Tab Order Setting parallel möglich)
```

---

## Quick Wins (Parallel möglich)

Diese Tasks sind unabhängig und können jederzeit gemacht werden:

| Task | Beschreibung | Aufwand |
|------|--------------|---------|
| Tab-Icons aktualisieren | 📅 → 🏆 für Erfolge | 5 min |
| Settings Tab-Namen | "Offen" → "Freie Meditation" etc. | 15 min |
| Lokalisierung | Neue Strings für DE/EN | 30 min |

---

## Empfohlener Start

**Woche 1-2: Phase 1 (Foundation)**
- Tab-Navigation refactoren
- SwiftData Model erstellen
- Keine sichtbare Änderung für User (außer Tab-Namen)

**Woche 3-4: Phase 2 (Core Tracker)**
- Tracker Tab bauen
- Quick-Logging implementieren
- Erstes testbares Tracker-Feature

**Danach:** Basierend auf Feedback priorisieren

---

## References

- `openspec/specs/app-vision.md` - Gesamtvision
- `openspec/specs/features/app-navigation.md` - Tab-Struktur
- `openspec/specs/features/trackers.md` - Tracker-Details
- `openspec/specs/features/tracker-widget.md` - Widget-Spec
- `openspec/specs/features/smart-reminders.md` - Reminder-Spec
- `openspec/specs/features/calendar-view.md` - Kalender-Visualisierung
- `openspec/specs/features/streaks-rewards.md` - Streak-Logik
