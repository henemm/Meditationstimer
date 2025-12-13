# Habit Tracking (Good & Bad Habits)

## Overview

Erweiterung des "Healthy Habits Haven" Konzepts um benutzerdefinierte Habits in zwei Kategorien:

**Good Habits**: Positive Gewohnheiten die der User aufbauen möchte (z.B. Hydration, Stretching, Journaling)

**Bad Habits**: Negative Gewohnheiten die der User bewusst wahrnehmen und später reduzieren möchte (z.B. Doomscrolling, Prokrastination, Snacking)

### Kernprinzip: Awareness vor Avoidance

Bad Habits nutzen ein zweistufiges Modell:
1. **Awareness-Modus**: Erst bewusst werden, dass und wann das Verhalten auftritt
2. **Avoidance-Modus**: Später aktiv vermeiden (optional, wenn bereit)

Diese Progression basiert auf psychologischen Erkenntnissen (Stages of Change) - man kann ein Verhalten nicht ändern, das man nicht wahrnimmt.

### Abgrenzung zu bestehenden Features

| Bestehend | Typ | Habit Tracking |
|-----------|-----|----------------|
| Meditation | Built-in Feature | ❌ Nicht Teil von Habit Tracking |
| Atem | Built-in Feature | ❌ Nicht Teil von Habit Tracking |
| Workouts | Built-in Feature | ❌ Nicht Teil von Habit Tracking |
| NoAlc | Built-in Feature | ❌ Nicht Teil von Habit Tracking |
| **Hydration** | User-Habit | ✅ Beispiel für Good Habit |
| **Doomscrolling** | User-Habit | ✅ Beispiel für Bad Habit |

---

## Requirements

### Requirement: Habit Creation
Das System SOLL es Usern ermöglichen, eigene Habits zu erstellen.

#### Scenario: Good Habit erstellen
- GIVEN User ist im Habit-Bereich
- WHEN User wählt "Good Habit hinzufügen"
- THEN kann User Name eingeben (z.B. "Wasser trinken")
- AND kann Icon/Emoji wählen
- AND kann Tracking-Art wählen (Zähler oder Ja/Nein)
- AND Habit erscheint in der Good Habits Liste

#### Scenario: Bad Habit erstellen
- GIVEN User ist im Habit-Bereich
- WHEN User wählt "Bad Habit hinzufügen"
- THEN kann User Name eingeben (z.B. "Doomscrolling")
- AND kann Icon/Emoji wählen
- AND Modus ist initial "Awareness" (nicht Avoidance)
- AND Habit erscheint in der Bad Habits Liste

#### Scenario: Vordefinierte Vorschläge
- GIVEN User möchte Habit hinzufügen
- WHEN Auswahl-Sheet öffnet
- THEN werden Vorschläge angezeigt:
  - Good: Hydration, Stretching, Lesen, Journaling, Spazieren
  - Bad: Doomscrolling, Prokrastination, Snacking, Nägel kauen
- AND User kann Vorschlag wählen oder eigenen erstellen

---

### Requirement: Good Habit Tracking
Das System SOLL das Logging positiver Gewohnheiten unterstützen.

#### Scenario: Zähler-basiertes Tracking
- GIVEN User hat Good Habit mit Zähler-Typ (z.B. "Gläser Wasser")
- WHEN User Habit einloggt
- THEN kann User Anzahl eingeben (z.B. 1, 2, 3...)
- AND Gesamtzahl für heute wird aktualisiert
- AND Eintrag wird mit Zeitstempel gespeichert

#### Scenario: Ja/Nein Tracking
- GIVEN User hat Good Habit mit Ja/Nein-Typ (z.B. "Heute gelesen")
- WHEN User Habit einloggt
- THEN wird Tag als "erledigt" markiert
- AND Mehrfaches Loggen am selben Tag ändert nichts

#### Scenario: Quick-Log aus Notification
- GIVEN Smart Reminder für Good Habit feuert
- WHEN User Notification sieht
- THEN sind Quick-Actions verfügbar
- AND Tap auf Action loggt direkt (ohne App öffnen)

---

### Requirement: Bad Habit Tracking (Awareness-Modus)
Das System SOLL das bewusste Wahrnehmen negativer Gewohnheiten ermöglichen.

#### Scenario: Awareness-Log erstellen
- GIVEN User hat Bad Habit im Awareness-Modus
- WHEN User bemerkt das Verhalten
- THEN kann User "Ich bemerke [Habit]" loggen
- AND optional Notiz hinzufügen (Trigger, Kontext)
- AND Zeitstempel wird gespeichert
- AND Zähler für heute erhöht sich

#### Scenario: Awareness-Streak
- GIVEN Bad Habit ist im Awareness-Modus
- AND User hat X Tage hintereinander mindestens 1x geloggt
- WHEN Streak angezeigt wird
- THEN zeigt "X Tage bewusst" (Awareness-Streak)
- AND Streak belohnt Selbst-Beobachtung, nicht Vermeidung

#### Scenario: Trigger-Dokumentation
- GIVEN User loggt Awareness-Moment
- WHEN User optionale Details hinzufügt
- THEN kann User Trigger auswählen/eingeben:
  - Wann? (Uhrzeit automatisch)
  - Wo? (Zuhause, Arbeit, Unterwegs)
  - Warum? (Langeweile, Stress, Gewohnheit)
- AND Daten werden für Pattern-Analyse gespeichert

---

### Requirement: Bad Habit Tracking (Avoidance-Modus)
Das System SOLL das aktive Vermeiden negativer Gewohnheiten unterstützen.

#### Scenario: Modus wechseln
- GIVEN User hat Bad Habit im Awareness-Modus
- WHEN User zu Avoidance wechseln möchte
- THEN wird Warnung angezeigt: "Streak-Typ ändert sich"
- AND nach Bestätigung wechselt Modus
- AND alter Awareness-Streak wird archiviert

#### Scenario: Avoidance-Streak
- GIVEN Bad Habit ist im Avoidance-Modus
- AND User hat X Tage OHNE Log (kein Verhalten)
- WHEN Streak angezeigt wird
- THEN zeigt "X Tage ohne [Habit]"
- AND jeder Log bricht Streak (wie bei NoAlc Wild)

#### Scenario: Rückfall dokumentieren
- GIVEN Bad Habit ist im Avoidance-Modus
- WHEN User das Verhalten doch zeigt
- THEN loggt User den Rückfall
- AND Streak bricht
- AND optional: Notiz zum Trigger

---

### Requirement: Kalender-Visualisierung
Das System SOLL Habits im Kalender visualisieren.

#### Scenario: Good Habit im Kalender
- GIVEN Kalendertag hat Good Habit Log
- WHEN Tag angezeigt wird
- THEN erscheint Indikator für diesen Habit
- AND Farbe zeigt Erfüllungsgrad (grün = erledigt)

#### Scenario: Bad Habit im Kalender (Awareness)
- GIVEN Kalendertag hat Awareness-Logs
- WHEN Tag angezeigt wird
- THEN erscheint Indikator
- AND zeigt Anzahl der bewussten Momente

#### Scenario: Bad Habit im Kalender (Avoidance)
- GIVEN Kalendertag OHNE Bad Habit Log
- WHEN Tag angezeigt wird
- THEN erscheint grüner Indikator (erfolgreiche Vermeidung)

### [OFFEN] Skalierung bei vielen Habits
- Aktuell: 3 konzentrische Ringe (Mindfulness, Workout, NoAlc)
- Bei vielen Custom Habits: Wie visualisieren?
- **Optionen:**
  - A: Mehr Ringe (max 5-6, dann unübersichtlich)
  - B: Aggregierter "Habits Score" + Detail bei Tap
  - C: User wählt 2-3 "Fokus-Habits" für Ringe, Rest in Liste
- **Entscheidung:** TBD nach UI-Prototyping

---

### Requirement: Smart Reminders Integration
Das System SOLL Erinnerungen für Custom Habits unterstützen.

#### Scenario: Reminder für Good Habit
- GIVEN User hat Good Habit erstellt
- WHEN User Reminder aktiviert
- THEN kann Uhrzeit gewählt werden
- AND Notification erscheint zur Erinnerung
- AND Quick-Actions ermöglichen direktes Loggen

#### Scenario: Reminder für Bad Habit (Awareness)
- GIVEN User hat Bad Habit im Awareness-Modus
- WHEN User "Reflektions-Reminder" aktiviert
- THEN erscheint Notification z.B. um 20:00
- AND fragt: "Hast du heute [Habit] bemerkt?"
- AND ermöglicht Logging falls vergessen

### [OFFEN] Skalierung bei vielen Reminders
- Bei 10+ Habits: Notification-Spam vermeiden
- **Optionen:**
  - A: Max X Habit-Reminders pro Tag (User-konfiguriert)
  - B: Gruppierte "Habit Check-In" Notification
  - C: Intelligente Priorisierung (nur bei verpassten Habits)
- **Entscheidung:** TBD

---

### Requirement: Streak-System
Das System SOLL Streaks für Custom Habits berechnen.

#### Scenario: Good Habit Streak
- GIVEN User loggt Good Habit täglich
- WHEN X Tage hintereinander geloggt
- THEN zeigt Streak "X Tage"
- AND Streak-Anzeige motiviert Kontinuität

#### Scenario: Streak mit Vergebung (Good Habits)
- GIVEN User hat Reward-basiertes System (wie NoAlc)
- WHEN User einen Tag verpasst
- THEN kann Reward konsumiert werden um Streak zu retten
- AND Rewards werden durch konsistentes Tracking verdient

#### Scenario: Awareness-Streak (Bad Habits)
- GIVEN Bad Habit im Awareness-Modus
- WHEN User X Tage hintereinander mindestens 1x geloggt hat
- THEN zeigt "X Tage bewusst"
- AND Streak belohnt aktive Selbst-Beobachtung

#### Scenario: Avoidance-Streak (Bad Habits)
- GIVEN Bad Habit im Avoidance-Modus
- WHEN User X Tage OHNE Log ist
- THEN zeigt "X Tage ohne [Habit]"
- AND jeder Log (Rückfall) bricht Streak

---

### Requirement: Insights und Patterns
Das System SOLL Muster in Bad Habit Daten erkennen.

#### Scenario: Tageszeit-Analyse
- GIVEN User hat mehrere Bad Habit Logs über Zeit
- WHEN Insights angezeigt werden
- THEN zeigt Verteilung nach Tageszeit
- AND identifiziert "Risiko-Zeiten" (z.B. "60% nachmittags")

#### Scenario: Trigger-Analyse
- GIVEN User hat Trigger bei Logs dokumentiert
- WHEN Insights angezeigt werden
- THEN zeigt häufigste Trigger
- AND ermöglicht gezielte Gegenmaßnahmen

#### Scenario: Trend-Anzeige
- GIVEN User trackt Bad Habit seit Wochen
- WHEN Insights angezeigt werden
- THEN zeigt Trend (mehr/weniger im Zeitverlauf)
- AND zeigt Fortschritt auf dem Weg zur Reduktion

---

## User Stories

### Good Habits
1. Als User möchte ich eigene positive Gewohnheiten tracken (z.B. Wasser trinken)
2. Als User möchte ich sehen wie viele Tage ich eine Gewohnheit durchgehalten habe
3. Als User möchte ich erinnert werden, wenn ich eine Gewohnheit vergesse
4. Als User möchte ich meinen Fortschritt im Kalender sehen

### Bad Habits
1. Als User möchte ich bewusst wahrnehmen, wann ich in Autopiloten verfalle
2. Als User möchte ich verstehen, was meine Bad Habits triggert
3. Als User möchte ich sehen, ob meine Awareness zunimmt
4. Als User möchte ich später von Awareness zu Avoidance wechseln können
5. Als User möchte ich meine Fortschritte über Zeit sehen

---

## Technical Notes

### Storage
- Custom Habits: SwiftData (nicht HealthKit - keine Standard-Typen)
- Ausnahme: Hydration könnte HKQuantityTypeIdentifier.dietaryWater nutzen
- Habit-Definitionen: Lokal mit iCloud-Sync (optional)

### Datenmodell (konzeptuell)
```
Habit
├── id: UUID
├── name: String
├── icon: String (SF Symbol oder Emoji)
├── type: .good | .bad
├── trackingMode: .counter | .yesNo | .awareness | .avoidance
├── createdAt: Date
└── isActive: Bool

HabitLog
├── id: UUID
├── habitId: UUID
├── timestamp: Date
├── value: Int? (für Counter)
├── note: String?
├── trigger: String? (für Bad Habits)
└── location: String? (optional)
```

### Integration mit bestehendem System
- Smart Reminders: Erweiterung des bestehenden Systems
- Kalender: Neue Ring-Typen oder aggregierte Darstellung
- Streaks: Erweiterung des StreakManager oder eigener HabitStreakManager

---

## Offene Fragen

1. **Kalender-Visualisierung**: Wie bei 5+ Habits? (siehe oben)
2. **Reminder-Skalierung**: Wie bei vielen Habits? (siehe oben)
3. **HealthKit-Integration**: Welche Good Habits sollen HealthKit nutzen?
4. **iCloud Sync**: Sollen Custom Habits geräteübergreifend synchen?
5. **Widget**: Soll es ein Habit-Widget geben?
6. **Watch**: Sollen Habits auf der Watch trackbar sein?

---

## Referenzen

- `.agent-os/standards/healthkit/date-semantics.md` (Forward Iteration für Streaks)
- `openspec/specs/features/noalc-tracker.md` (Pattern für Streak mit Rewards)
- `openspec/specs/features/smart-reminders.md` (Reminder-System)
