# Healthy Habits Haven - App Vision

## Overview

"Healthy Habits Haven" is a wellness app that helps build positive habits and consciously notice negative autopilot behaviors.

"Healthy Habits Haven" ist eine Wellness-App die dabei hilft, positive Gewohnheiten aufzubauen und negative Autopiloten bewusst wahrzunehmen.

**Core Features / Kernfunktionen:**
- Meditation & Breathing Exercises (Timer-based) / Meditation & Atemübungen (Timer-basiert)
- HIIT Workouts
- NoAlc Tracking (Alcohol abstinence / Alkohol-Abstinenz)
- Good Trackers (custom positive habits) / Positiv-Tracker (eigene positive Gewohnheiten)
- Saboteur Trackers (Awareness-Tracking) / Saboteur-Tracker (Bewusstseins-Tracking)

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
| US-2.2 | Als Henning möchte ich **schnell notieren wenn ich einen Autopiloten bemerke** (Saboteur Tracker Awareness). | 🔲 |
| US-2.3 | Als Henning möchte ich **positive Gewohnheiten als erledigt markieren** (Good Tracker). | 🔲 |
| US-2.4 | Als Henning wird meine **Meditation automatisch geloggt** nach Session-Ende. | 🔲 |

#### Akzeptanzkriterien (Epic 2)

**US-2.1: NoAlc loggen**
- Bestehendes System bleibt (Steady/Easy/Wild Levels)
- Quick-Actions aus Notification
- HealthKit-Integration (numberOfAlcoholicBeverages)

**US-2.2: Saboteur Tracker Awareness loggen**
- Optional: Levels OR simple counter (User chooses when creating)
- Optional note/trigger
- Timestamp automatic
- GIVEN Saboteur Tracker has Levels configured
- WHEN User logs
- THEN can choose Level

**US-2.3: Good Tracker loggen**
- Optional: Counter (how many) OR Yes/No (done)
- User chooses tracking type when creating Tracker
- GIVEN Good Tracker is "Yes/No" type
- WHEN User logs once
- THEN day is marked as done

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
- ONE reminder per Tracker type (max 1 per day)
- Reminder fires ONLY if not yet logged
- User configures time per Tracker type
- GIVEN Reminder for "Hydration" is 20:00
- AND User has not logged today
- WHEN 20:00 reached
- THEN Reminder appears

- GIVEN User has already logged today
- WHEN 20:00 reached
- THEN NO Reminder appears

**US-3.2: Quick-Action aus Notification**
- Notification has Action-Buttons
- NoAlc: Steady / Easy / Wild
- Good Tracker: +1 or "Done"
- Saboteur Tracker: "Noticed" or Level-Buttons
- GIVEN Reminder notification appears
- WHEN User taps Quick-Action
- THEN Log is created WITHOUT opening app

**US-3.3: Abend-Check-In / Evening Check-In**
- Variant of Smart Reminder
- Checks ALL open Trackers at once
- Shows: "You haven't logged yet: Hydration, NoAlc"
- Quick-Actions for the open Trackers

---

### Epic 4: Motivation & Fortschritt

| ID | Story | Status |
|----|-------|--------|
| US-4.1 | Als Henning möchte ich meine **aktuelle Streak-Zahl prominent sehen**. | 🔲 |
| US-4.2 | Als Henning möchte ich im **Kalender sehen welche Tage erfolgreich waren**. | 🔲 |
| US-4.3 | Als Henning möchte ich meine **verdienten Rewards/Vergebungen sehen**. | 🔲 |
| US-4.4 | Als Henning möchte ich **Streaks für verschiedene Trackers sehen**. | 🔲 |

#### Akzeptanzkriterien (Epic 4)

**US-4.1: Streak-Zahl prominent sehen**
- Main Streaks (Meditation, Workout, NoAlc) always visible
- Custom Tracker Streaks: only when Streak enabled
- Position: TBD after Layout-Redesign

**US-4.2: Kalender-Übersicht / Calendar Overview**
- Existing system: Concentric rings per activity type
- Custom Trackers: TBD (Scaling problem with many Trackers)
- Tap on day shows details

**US-4.3: Rewards sehen**
- Show current Reward balance
- "3 Rewards available" or "0 used of 2"
- Reward system is CONFIGURABLE per Tracker
- GIVEN Tracker has Rewards enabled
- WHEN 7 day Streak reached
- THEN +1 Reward earned

**US-4.4: Multiple Streaks / Mehrere Streaks**
- Overview of all active Streaks
- Sorted by length or alphabet
- GIVEN User has 5 Trackers with Streak enabled
- WHEN Streak overview opened
- THEN shows all 5 Streaks with current status

**Configurability per Tracker / Konfigurierbarkeit pro Tracker:**
- Streak: Yes/No (Default: Yes for main types)
- Rewards: Yes/No (Default: Yes for NoAlc, No for others)

---

### Epic 5: Tracker Management / Tracker-Verwaltung

| ID | Story | Status |
|----|-------|--------|
| US-5.1 | Als Henning möchte ich **eigene positive Gewohnheiten anlegen** (Good Tracker). | 🔲 |
| US-5.2 | Als Henning möchte ich **Autopiloten/Saboteure definieren** (Saboteur Tracker). | 🔲 |
| US-5.3 | Als Henning möchte ich **Trackers anpassen oder entfernen**. | 🔲 |
| US-5.4 | Als Henning möchte ich bei Saboteur Trackers **von Awareness zu Avoidance wechseln**. | 🔲 |

#### Akzeptanzkriterien (Epic 5)

**US-5.1: Good Tracker erstellen / Create Good Tracker**
- Enter name (required)
- Choose Icon/Emoji (optional, default available)
- Choose tracking type: Counter OR Yes/No
- Optional: Define Levels (like NoAlc)
- Optional: Enable Streak (Default: Yes)
- Optional: Enable Rewards (Default: No)
- Optional: Configure Smart Reminder
- Predefined suggestions: Hydration, Stretching, Reading, Journaling, Walking

**US-5.2: Saboteur Tracker definieren / Define Saboteur Tracker**
- Enter name (required)
- Choose Icon/Emoji (optional)
- Mode: Awareness (Default) or Avoidance
- Optional: Define Levels
- Optional: Enable Streak
- Optional: Enable Rewards
- Predefined suggestions: Doomscrolling, Procrastination, Snacking, Nail biting

**US-5.3: Tracker bearbeiten/löschen / Edit/Delete Tracker**
- All fields editable (Name, Icon, Tracking type, etc.)
- Delete with confirmation
- GIVEN Tracker has Logs
- WHEN User wants to delete
- THEN Warning: "All logs will be lost"

**US-5.4: Switch from Awareness to Avoidance / Von Awareness zu Avoidance wechseln**
- Only for Saboteur Trackers
- Warning: "Your Awareness Streak will be archived"
- After switch: New Avoidance Streak starts at 0
- Old Streak remains visible in history
- GIVEN Saboteur Tracker in Awareness mode
- WHEN User switches to Avoidance
- THEN Awareness Streak is saved
- AND new Avoidance Streak begins

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

### 4. Awareness Before Avoidance / Awareness vor Avoidance
Saboteur Trackers: First **become aware**, then (optionally) **avoid**.

---

## Scope (MVP)

**Included / Enthalten:**
- iPhone App
- Local data storage (SwiftData) / Lokale Datenspeicherung (SwiftData)
- Smart Reminders (like NoAlc) / Smart Reminders (wie NoAlc)

**Not included (later) / Nicht enthalten (später):**
- iCloud Sync
- Apple Watch App
- Widget
- Calendar visualization for Custom Trackers (TBD)

---

## References / Referenzen

- `openspec/specs/features/trackers.md` - Detail-Spec for Good/Saboteur Trackers
- `openspec/specs/features/meditation-timer.md` - Meditation Feature
- `openspec/specs/features/noalc-tracker.md` - NoAlc Pattern (model for Smart Reminders)
