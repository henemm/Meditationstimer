# Projekt-Backlog: Meditationstimer

Dieses Dokument fasst den aktuellen Stand der Entwicklung, abgeschlossene Aufgaben und die nächsten Schritte zusammen.

## Zusammenfassung

Schwerpunkte dieser Iteration:
1) HealthKit-Race-Conditions zuverlässig beheben (Sitzung erst nach erfolgreichem Speichern schließen).
2) Live Activity/Dynamic Island und Lock Screen visuell straffen (zentrierter Timer, kompakte Breite, sinnvolle Labels).

Zusätzlich: Kleinere UI-/UX-Polish (Icons, Settings) und Fehlerbehebungen (z. B. fehlende `scenePhase`-Deklaration in der Atem‑Preview).

---

## ✅ Abgeschlossene Aufgaben

1.  HealthKit-Race-Condition in Offen/Atem/Workout beseitigt
    - Zentralisierte End‑Flows (await Speichern → dann Activity beenden/Ansicht schließen).
    - Dateien: `OffenView.swift` (endSession), `AtemView.swift` (SessionCard.endSession), `WorkoutsView.swift` (WorkoutRunnerView.endSession).

2.  Live Activity/Dynamic Island straffer gestaltet
    - Lock Screen: Timer strikt zentriert; „Minuten“ nur bei Restzeit ≥ 60 s.
    - Dynamic Island (kompakt): leading leer, trailing nur Timer (monospaced) → schmal.
    - Dynamic Island (expanded): nur Timer im Center, fixedSize (oder Phase+Timer kompakt – je nach Variante, aktuell Timer‑fokussiert).
    - Datei: `MeditationstimerWidgetLiveActivity.swift`.

3.  Offen: Phase‑Wechsel korrekt in Live Activity
    - Beim Übergang Phase 1 → Phase 2 wird die bestehende Activity mit neuem `endDate`/`phase` upgedatet (nicht beendet/neu gestartet).
    - Datei: `OffenView.swift`.

4.  Settings erweitert
    - „Meditation als Yoga‑Workout loggen“ (Offen/Atem nutzen Yoga statt Mindfulness, optional).
    - Datei: `SettingsSheet.swift`.

5.  UI‑Feinschliff Workouts
    - Wiederholungs‑Icon von 🔁/➿ auf neutrales „↻“ umgestellt (weniger „Button‑haft“).
    - Datei: `WorkoutsView.swift`.

6.  Fehlerbehebung Atem Preview
    - Fehlende `@Environment(\.scenePhase)`‑Deklaration in `SessionCard` ergänzt (Build‑Fehler behoben).
    - Datei: `AtemView.swift`.

7.  Falsches Auto‑Beenden beim App‑Wechsel zurückgenommen
    - Entfernte scenePhase‑Auto‑Ende in Offen/Atem/Workout (verursachte Gong/Abbruch beim normalen App‑Wechsel).
    - Dateien: `OffenView.swift`, `AtemView.swift`, `WorkoutsView.swift`.

---

## ⏳ Offene Aufgaben

1.  Live Preview (Canvas) – Stabilität final prüfen
    - Ziel: Der frühere, einfache Preview‑Pfad zeigt zuverlässig Inhalt (ohne zusätzliche Fallback‑Previews).
    - Aktion: Konkrete Canvas‑Fehlermeldung sammeln und gezielt fixen (Availability/Gates), ohne neue Varianten zu bauen.

2.  Dynamic Island – finale Variante festzurren
    - Aktuell: Kompakt trailing‑Timer, Expanded nur Timer mittig (fixedSize).
    - Optional: Phase+Timer im Expanded als Alternative; Entscheidung per Review auf Gerät.

3.  Optionaler Debug‑Schalter
    - „Alle Live Activities beenden“ (nur Debug). Evaluieren, ob sinnvoll – Standardverhalten beim App‑Wechsel bleibt: nichts automatisch beenden.

4.  Nachtests HealthKit
    - Gerätespezifische Verifikation: Offen/Atem/Workout speichern zuverlässig (Fehlschlag‑Handling/Toast vorhanden).

5.  Kleiner UX‑Polish
    - Typografie/Abstände Lock Screen und Expanded ggf. minimal justieren.

—

Stand: 07.10.2025
