# Healthy Habits Haven - App Vision

## Overview

"Healthy Habits Haven" ist eine Wellness-App die dabei hilft, positive Gewohnheiten aufzubauen und negative Autopiloten bewusst wahrzunehmen.

**Kernfunktionen:**
- Meditation & Atemübungen (Timer-basiert)
- HIIT Workouts
- NoAlc Tracking (Alkohol-Abstinenz)
- Good Habits (eigene positive Gewohnheiten)
- Bad Habits / Saboteure (Awareness-Tracking)

---

## Persona

### Henning (Primary User)

**Nutzungsverhalten:**
- Nutzt App morgens, abends, und spontan
- Öffnet App für: Meditation starten, Logging, Reminder-Reaktion, Motivation

**Motivatoren:**
- Streak-Zahlen ("42 Tage!")
- Kalender-Übersicht (grüne Tage sehen)
- Rewards/Vergebungs-System

**Bedürfnisse:**
- Schneller Start (1-2 Taps)
- Einfaches Logging (Quick-Log)
- Nicht-nervige Reminders (nur wenn nötig)
- Sichtbarer Fortschritt

---

## Epics & User Stories

### Epic 1: Sessions starten

| ID | Story | Status |
|----|-------|--------|
| US-1.1 | Als Henning möchte ich mit **1-2 Taps eine Meditation starten**, damit ich nicht durch Konfiguration aus dem Flow komme. | 🔲 |
| US-1.2 | Als Henning möchte ich vor dem Start **bewusst die Dauer wählen**, damit ich die Meditation an meine verfügbare Zeit anpasse. | 🔲 |
| US-1.3 | Als Henning möchte ich zwischen **Offen, Atem und anderen Arten wählen**, damit ich je nach Stimmung die passende Übung mache. | 🔲 |
| US-1.4 | Als Henning möchte ich schnell ein **HIIT-Workout starten**, damit ich körperliche Aktivität tracken kann. | 🔲 |

#### Akzeptanzkriterien (Epic 1)

**US-1.1 + US-1.2: Schnell starten mit Dauer-Wahl**
- App merkt sich letzte gewählte Dauer (AppStorage)
- Start-Button startet sofort mit letzter Dauer
- Dauer-Picker ist sichtbar aber optional
- GIVEN App wurde mit 10 Min gestartet
- WHEN User nächstes Mal öffnet
- THEN ist 10 Min vorausgewählt

**US-1.3: Meditationsart wählen**
- TBD nach App-Layout Redesign
- Aktuell: Tabs (Offen, Atem, Workouts, Frei)
- Ziel: Einheitlicher, schneller Zugang zu allen Arten

**US-1.4: Workout starten**
- Gleiche Logik: Letzte Einstellung merken
- Preset-Programme oder freie Konfiguration

---

### Epic 2: Quick-Logging

| ID | Story | Status |
|----|-------|--------|
| US-2.1 | Als Henning möchte ich meinen **Alkohol-Status schnell loggen** (NoAlc). | 🔲 |
| US-2.2 | Als Henning möchte ich **schnell notieren wenn ich einen Autopiloten bemerke** (Bad Habit Awareness). | 🔲 |
| US-2.3 | Als Henning möchte ich **positive Gewohnheiten als erledigt markieren** (Good Habit). | 🔲 |
| US-2.4 | Als Henning wird meine **Meditation automatisch geloggt** nach Session-Ende. | 🔲 |

#### Akzeptanzkriterien (Epic 2)

**US-2.1: NoAlc loggen**
- Bestehendes System bleibt (Steady/Easy/Wild Levels)
- Quick-Actions aus Notification
- HealthKit-Integration (numberOfAlcoholicBeverages)

**US-2.2: Bad Habit Awareness loggen**
- Optional: Levels ODER einfacher Zähler (User wählt beim Erstellen)
- Optionale Notiz/Trigger
- Zeitstempel automatisch
- GIVEN Bad Habit hat Levels konfiguriert
- WHEN User loggt
- THEN kann Level gewählt werden

**US-2.3: Good Habit loggen**
- Optional: Zähler (wie viele) ODER Ja/Nein (erledigt)
- User wählt Tracking-Art beim Habit-Erstellen
- GIVEN Good Habit ist "Ja/Nein" Typ
- WHEN User einmal loggt
- THEN ist Tag als erledigt markiert

**US-2.4: Meditation automatisch loggen**
- Nach Session-Ende → HealthKit (mindfulSession)
- Nur bei erfolgreicher Session (nicht bei Cancel)
- Dauer = Phase 1 Dauer

**UI-Platzierung: TBD nach Layout-Redesign**
- Vorerst: Zugang über Smart Reminders/Notifications

---

### Epic 3: Reminder & Notifications

| ID | Story | Status |
|----|-------|--------|
| US-3.1 | Als Henning möchte ich **nur erinnert werden wenn ich noch nicht geloggt habe** (Smart Reminder). | 🔲 |
| US-3.2 | Als Henning möchte ich **direkt aus der Notification loggen** (Quick-Action). | 🔲 |
| US-3.3 | Als Henning möchte ich **abends an offene Logs erinnert werden** (Check-In). | 🔲 |

#### Akzeptanzkriterien (Epic 3)

**US-3.1: Smart Reminder (NoAlc-Pattern)**
- Pro Habit-Typ EIN Reminder (max 1 pro Tag)
- Reminder feuert NUR wenn noch nicht geloggt
- User konfiguriert Uhrzeit pro Habit-Typ
- GIVEN Reminder für "Hydration" ist 20:00
- AND User hat heute noch nicht geloggt
- WHEN 20:00 erreicht
- THEN erscheint Reminder

- GIVEN User hat heute bereits geloggt
- WHEN 20:00 erreicht
- THEN erscheint KEIN Reminder

**US-3.2: Quick-Action aus Notification**
- Notification hat Action-Buttons
- NoAlc: Steady / Easy / Wild
- Good Habit: +1 oder "Erledigt"
- Bad Habit: "Bemerkt" oder Level-Buttons
- GIVEN Reminder-Notification erscheint
- WHEN User tippt Quick-Action
- THEN wird Log erstellt OHNE App zu öffnen

**US-3.3: Abend-Check-In**
- Variante des Smart Reminders
- Prüft ALLE offenen Habits auf einmal
- Zeigt: "Du hast noch nicht geloggt: Hydration, NoAlc"
- Quick-Actions für die offenen Habits

---

### Epic 4: Motivation & Fortschritt

| ID | Story | Status |
|----|-------|--------|
| US-4.1 | Als Henning möchte ich meine **aktuelle Streak-Zahl prominent sehen**. | 🔲 |
| US-4.2 | Als Henning möchte ich im **Kalender sehen welche Tage erfolgreich waren**. | 🔲 |
| US-4.3 | Als Henning möchte ich meine **verdienten Rewards/Vergebungen sehen**. | 🔲 |
| US-4.4 | Als Henning möchte ich **Streaks für verschiedene Habits sehen**. | 🔲 |

#### Akzeptanzkriterien (Epic 4)

**US-4.1: Streak-Zahl prominent sehen**
- Haupt-Streaks (Meditation, Workout, NoAlc) immer sichtbar
- Custom Habit Streaks: nur wenn Streak aktiviert
- Position: TBD nach Layout-Redesign

**US-4.2: Kalender-Übersicht**
- Bestehendes System: Konzentrische Ringe pro Aktivitäts-Typ
- Custom Habits: TBD (Skalierungs-Problem bei vielen Habits)
- Tap auf Tag zeigt Details

**US-4.3: Rewards sehen**
- Aktuelle Reward-Balance anzeigen
- "3 Rewards verfügbar" oder "0 verbraucht von 2"
- Reward-System ist KONFIGURIERBAR pro Habit
- GIVEN Habit hat Rewards aktiviert
- WHEN 7 Tage Streak erreicht
- THEN +1 Reward verdient

**US-4.4: Mehrere Streaks**
- Übersicht aller aktiven Streaks
- Sortiert nach Länge oder Alphabet
- GIVEN User hat 5 Habits mit Streak aktiviert
- WHEN Streak-Übersicht geöffnet
- THEN zeigt alle 5 Streaks mit aktuellem Stand

**Konfigurierbarkeit pro Habit:**
- Streak: Ja/Nein (Default: Ja für Haupt-Typen)
- Rewards: Ja/Nein (Default: Ja für NoAlc, Nein für andere)

---

### Epic 5: Habit-Verwaltung

| ID | Story | Status |
|----|-------|--------|
| US-5.1 | Als Henning möchte ich **eigene positive Gewohnheiten anlegen** (Good Habit). | 🔲 |
| US-5.2 | Als Henning möchte ich **Autopiloten/Saboteure definieren** (Bad Habit). | 🔲 |
| US-5.3 | Als Henning möchte ich **Habits anpassen oder entfernen**. | 🔲 |
| US-5.4 | Als Henning möchte ich bei Bad Habits **von Awareness zu Avoidance wechseln**. | 🔲 |

#### Akzeptanzkriterien (Epic 5)

**US-5.1: Good Habit erstellen**
- Name eingeben (Pflicht)
- Icon/Emoji wählen (optional, Default vorhanden)
- Tracking-Art wählen: Zähler ODER Ja/Nein
- Optional: Levels definieren (wie NoAlc)
- Optional: Streak aktivieren (Default: Ja)
- Optional: Rewards aktivieren (Default: Nein)
- Optional: Smart Reminder konfigurieren
- Vordefinierte Vorschläge: Hydration, Stretching, Lesen, Journaling, Spazieren

**US-5.2: Bad Habit definieren**
- Name eingeben (Pflicht)
- Icon/Emoji wählen (optional)
- Modus: Awareness (Default) oder Avoidance
- Optional: Levels definieren
- Optional: Streak aktivieren
- Optional: Rewards aktivieren
- Vordefinierte Vorschläge: Doomscrolling, Prokrastination, Snacking, Nägel kauen

**US-5.3: Habit bearbeiten/löschen**
- Alle Felder editierbar (Name, Icon, Tracking-Art, etc.)
- Löschen mit Bestätigung
- GIVEN Habit hat Logs
- WHEN User löschen will
- THEN Warnung: "Alle Logs gehen verloren"

**US-5.4: Von Awareness zu Avoidance wechseln**
- Nur für Bad Habits
- Warnung: "Dein Awareness-Streak wird archiviert"
- Nach Wechsel: Neuer Avoidance-Streak startet bei 0
- Alter Streak bleibt in Historie sichtbar
- GIVEN Bad Habit im Awareness-Modus
- WHEN User zu Avoidance wechselt
- THEN wird Awareness-Streak gespeichert
- AND neuer Avoidance-Streak beginnt

---

### Epic 6: Settings (TBD)

*Settings-Stories werden bei Verfeinerung der anderen Epics identifiziert.*

---

## Design-Prinzipien

### 1. Quick-Log First
Jede Logging-Aktion muss in **max 2 Taps** erledigt sein.

### 2. Smart, Not Annoying
Reminders nur wenn **wirklich nötig** (noch nicht geloggt).

### 3. Motivation durch Sichtbarkeit
**Streaks, Kalender, Rewards** immer prominent sichtbar.

### 4. Awareness vor Avoidance
Bad Habits: Erst **bewusst werden**, dann (optional) **vermeiden**.

---

## Scope (MVP)

**Enthalten:**
- iPhone App
- Lokale Datenspeicherung (SwiftData)
- Smart Reminders (wie NoAlc)

**Nicht enthalten (später):**
- iCloud Sync
- Apple Watch App
- Widget
- Kalender-Visualisierung für Custom Habits (TBD)

---

## Referenzen

- `openspec/specs/features/habit-tracking.md` - Detail-Spec für Good/Bad Habits
- `openspec/specs/features/meditation-timer.md` - Meditation Feature
- `openspec/specs/features/noalc-tracker.md` - NoAlc Pattern (Vorbild für Smart Reminders)
