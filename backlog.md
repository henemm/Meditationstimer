# Projekt-Backlog: Meditationstimer

Dieses Dokument fasst den aktuellen Stand der Entwicklung, abgeschlossene Aufgaben und die nächsten Schritte zusammen.

## Zusammenfassung

Das Hauptziel war die Behebung von zwei Problemen:
1.  Ein Fehler, bei dem Meditationen und Workouts nicht zuverlässig in Apple HealthKit gespeichert wurden.
2.  Diverse UI-Fehler in der Live Activity (Sperrbildschirm) und der Dynamic Island.

Der HealthKit-Fehler wurde als Race Condition identifiziert, bei der die App-Ansicht geschlossen wurde, bevor der asynchrone Speichervorgang abgeschlossen war. Die UI-Fehler betrafen die Zentrierung, die Breite und die bedingte Anzeige von Elementen.

---

## ✅ Abgeschlossene Aufgaben

1.  **HealthKit-Bug in `OffenView.swift` behoben**
    *   **Änderung:** Die Logik zum Beenden der Sitzung wurde in einer zentralen `endSession()`-Funktion zusammengefasst. Diese stellt sicher, dass der HealthKit-Speichervorgang immer vor der Beendigung der Live Activity und dem Schließen der Ansicht abgeschlossen wird.
    *   **Status:** ✔️ Abgeschlossen

2.  **HealthKit-Bug in `AtemView.swift` behoben**
    *   **Änderung:** Analog zu `OffenView` wurde die `endSession()`-Logik innerhalb der `SessionCard` zentralisiert, um das korrekte Speichern in HealthKit zu gewährleisten.
    *   **Status:** ✔️ Abgeschlossen

3.  **UI-Fehler in Live Activity & Dynamic Island behoben**
    *   **Datei:** `MeditationstimerWidgetLiveActivity.swift`
    *   **Änderungen:**
        *   Der Timer auf dem Sperrbildschirm wird nun korrekt zentriert.
        *   Das "Minuten"-Label wird nur noch bei Restzeiten > 59 Sekunden angezeigt.
        *   Die Breite der Dynamic Island wurde so angepasst, dass sie sich nicht mehr über die volle Bildschirmbreite erstreckt.
    *   **Status:** ✔️ Abgeschlossen

---

## ⏳ Offene Aufgaben

1.  **HealthKit-Bug in `WorkoutsView.swift` beheben**
    *   **Problem:** Der gleiche Race-Condition-Fehler wie in den anderen Ansichten existiert auch hier. Bisherige Korrekturversuche sind an Compiler-Fehlern gescheitert, da dieser Ansicht Abhängigkeiten zu anderen Teilen des Codes fehlen.
    *   **Nächste Schritte:**
        *   **1. Abhängigkeiten auflösen (Compiler-Fehler beheben):**
            *   Die UI-Komponente `GlassCard` muss für `WorkoutsView` verfügbar gemacht werden. Der beste Ansatz ist, die `GlassCard`-Definition in eine eigene, neue Datei (`Meditationstimer iOS/UI/GlassCard.swift`) auszulagern, damit sie global wiederverwendet werden kann.
            *   Die `SettingsSheet`-Ansicht muss ebenfalls verfügbar gemacht werden.
        *   **2. HealthKit-Logik korrigieren:**
            *   Nachdem die Compiler-Fehler behoben sind, wird die Logik zum Beenden des Workouts in der `WorkoutRunnerView` (innerhalb von `WorkoutsView.swift`) zentralisiert.
            *   Eine `endSession()`-Funktion wird erstellt, die sicherstellt, dass `HealthKitManager.shared.logMindfulness()` immer **vor** dem Schließen der Ansicht (`onClose()`) aufgerufen und abgeschlossen wird.
    *   **Status:** 🚧 In Arbeit
