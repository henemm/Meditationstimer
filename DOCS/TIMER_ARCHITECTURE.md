# Timer-Architektur (Kurzreferenz)

> STATUS: REVIEWED — updated 2025-10-12 (architecture and ownership rules validated)

Ziel: Klar dokumentieren, dass in der App jeweils nur ein Timer aktiv ist, aber die konkrete Timer‑Implementierung tab‑spezifisch sein darf. Das sorgt für Sicherheit (kein unbeabsichtigtes Überschreiben) und erlaubt es, die Funktionalität pro Tab getrennt weiterzuentwickeln.

Kurzüberblick
- Laufzeitregel: Es gibt immer maximal einen aktiven Timer / Live Activity gleichzeitig.
- Implementierung: Jeder "Tab" (z. B. Offen, Atem, Workouts) kann seine eigene Timer‑Engine verwenden (z. B. `TwoPhaseTimerEngine`, `SomeOtherEngine`).
- Ownership: Der Tab, der den Timer startet, ist auch verantwortlich für dessen sauberes Beenden (oder für ein wohl definiertes Handover an eine andere Engine).

Wo im Code sich die relevanten Implementierungen befinden (aktueller Stand):
- `Meditationstimer iOS/Tabs/OffenView.swift` — Offen‑Tab UI / Start/Stop Logik
- `Services/TwoPhaseTimerEngine.swift` — Zwei‑Phasen Timer Engine
- `Services/LiveActivityController.swift` — zentrale ActivityKit‑Wrapper (start/update/end)
- `Meditationstimer iOS/LiveActivityController.swift` — iOS target copy of the controller
- `Meditationstimer iOS/Tabs/AtemView.swift` — Atem‑Tab (UI)
- `Meditationstimer iOS/Tabs/WorkoutsView.swift` — Workouts‑Tab (UI)
- `Models/BreathPreset.swift` — presets used by engine(s)

Kontrakt (kleine, klare Spezifikation)
- Inputs: Start-Aufruf mit (startDate, duration, phaseInfo) durch den Tab/Engine.
- Outputs: Periodische Updates an Activity/Widget, finaler End-Aufruf.
- Fehlerzustände: Cancel/Abbruch, App‑Termination, Nicht‑verfügbares ActivityKit.
- Erfolgsbedingung: Nach Start ist genau ein Timer sichtbar/aktiv; bei Wechsel des aktiven Tabs wird der vorherige Timer sauber beendet oder idempotent überschrieben.

Wahrscheinliche Edge‑Cases
- Zwei Tabs starten fast gleichzeitig einen Timer → Race: es muss eine deterministische Ownership‑Regel geben.
- App wird terminiert während Live Activity läuft → ActivityKit kann extern weiterlaufen; App‑Start muss Zustand rekonstruieren.
- Widget/AppIntents versuchen, Activity zu aktualisieren, obwohl sie nicht Owner sind → Updates sollten nur mit gültigem Token/ID angenommen werden.

Empfehlungen (konkrete Maßnahmen)
1) Persistente Dokumentation: Diese Datei (DOCS/TIMER_ARCHITECTURE.md) ist der richtige Ort für die Architektur-Quickreference. Sie ist im Repo sichtbar für andere Chats/Automationen.
 2) Runtime‑Guard: In `LiveActivityController` eine einfache, globale Ownership‑Prüfung/Mutex implementieren:
    - Wenn ein Start aufgerufen wird, prüfe `if LiveActivityController.shared.isActive && owner != requestingOwner` → entweder `end()` + `start()` oder ablehnen mit Debug‑Log.
    - Konvention: Caller sollten beim Starten einen `ownerId` String übergeben, z. B. `"OffenTab"`, `"AtemTab"`, `"WorkoutsTab"`.
       Dieser String wird protokolliert und bei Konflikten für deterministisches Verhalten genutzt.
3) Code‑Kommentare: Ergänze am Kopf jeder Tab‑Datei einen kurzen Kommentar mit dem Hinweis, dass der Tab eine eigene Engine besitzt und wie Ownership funktioniert.
4) Tests: Ergänze 1–2 kleine UI/Unit‑Tests, die sicherstellen, dass bei RapidSwitching nur ein Activity läuft.
5) CI/Policy: Überlege, `stable/*` Branches als geschützte Branches einzurichten (GitHub branch protection) – verhindert versehentliche force‑pushes.

Vorschlag für nächsten Schritt (ich kann das sofort umsetzen):
- Ich erstelle kurze Code‑Kommentare in den Tab‑Dateien (z. B. `OffenView.swift`) und füge in `Services/LiveActivityController.swift` eine kleine Ownership‑Guard‑Prüfung hinzu (keine funktionale Änderung, nur Defensive‑Check + Debug‑Log). Danach führe ich einen schnellen Lint/Build‑Check durch.

 Status: Runtime‑Guard implementiert in `Services/LiveActivityController.swift` und `Meditationstimer iOS/LiveActivityController.swift`. Tabs sollten `ownerId` beim Starten übergeben (OffenView wurde aktualisiert).

 AI Notes: Wenn du AI-spezifische Hinweise zentral sehen möchtest, ich kann `DOCS/AI_NOTES.md` erstellen und dort alles konsolidieren.

Fragen an dich
- Möchtest du, dass ich die Runtime‑Guard jetzt automatisch einbaue (ich kann das tun), oder bevorzugst du nur die Dokumentation und manuelle Änderungen später?
- Sollen die per‑Tab Implementierungen in diesem Dokument noch detaillierter aufgelistet/erklärt werden (z. B. private helper, persistente state files) — kurz oder ausführlich?

Anmerkung zu AI‑Hinweisen
- Du hast erwähnt, dass du bereits Informationen für die AI in einigen Dateien abgelegt hast. Wenn du möchtest, kann ich alle diese Hinweise sammeln und in `DOCS/AI_NOTES.md` konsolidieren, damit andere Chat‑Sitzungen sie direkt finden.

---

Date created: 2025-10-10
