# Chronik der Fehlversuche – Meditationstimer Timer-Bug

> STATUS: REVIEWED (archival) — updated 2025-10-12. This document records previous failed attempts and is kept for audit/history.

Diese Datei dokumentiert alle bisherigen Fehlversuche und Debug-Ansätze zur Lösung des Problems, dass der Timer nach "Beenden" nicht zuverlässig gestoppt wird.

---

## 1. Debug-Instrumentierung in endSession
- engine.cancel() immer zuerst
- Nach jedem Schritt Debug-Log (print)
- Audio/LiveActivity nach Timer-Stopp
- Ergebnis: Keine nachhaltige Verbesserung, Problem blieb bestehen

## 2. Commit & Rollback-Strategie
- Vor jedem größeren Versuch ein Commit
- Fehlversuche sofort per git reset zurückgesetzt
- Ergebnis: Saubere Historie, aber keine Lösung des Problems

## 3. Analyse der Timer-Engine
- Prüfung von TwoPhaseTimerEngine.swift
- engine.cancel() funktioniert isoliert korrekt
- Problem liegt in Integration mit UI/LiveActivity

## 4. Race-Condition-Analyse
- Prüfung auf parallele Tasks, Timer, WorkItems
- Hypothese: UI-States und Tasks werden nicht atomar zurückgesetzt
- Ergebnis: Problem nicht gelöst

## 5. Vorschlag: Zentrale resetSession()-Funktion
- Idee: Alle States, Timer, WorkItems, Audio, LiveActivity in einer Funktion zurücksetzen
- Bisher nicht als atomare Funktion umgesetzt

## 6. Mehrfache Rückfragen und Bestätigungen
- Prüfung, ob Änderungen wirklich greifen
- Analyse, ob die bisherigen Versuche eine vollständige Lösung bieten

## 7. Einzelne State-Resets und WorkItem-Cancels
- Verteilte Resets in mehreren Funktionen
- Keine zentrale, garantierte Rücksetzung

---

# Fehlversuch 8 – Zentrale Reset-Logik für Timer-Session

## Vorgehen
- Implementiere eine zentrale Funktion `resetSession()` in OffenView und AtemView.
- Diese Funktion setzt ALLE relevanten State-Variablen, Timer, DispatchWorkItems, Audio und LiveActivity in EINEM Schritt zurück.
- Sie wird nach jedem Abbruch oder Ende der Session aufgerufen, unabhängig vom Grund.
- Ziel: Atomarer, synchroner Reset aller UI- und Hintergrundzustände, um Race-Conditions und hängende UI zu verhindern.

## Umsetzung
- Funktion wird in beiden Views angelegt und in endSession sowie bei Tab-Wechsel/Abbruch aufgerufen.
- Alle State-Variablen (sessionStart, didPlayPhase2Gong, pendingEndStop, etc.) werden zurückgesetzt.
- Alle Timer/WorkItems werden gecancelt.
- LiveActivity und Audio-Session werden gestoppt.
- UI springt garantiert auf .idle und schließt Overlays.

## Ergebnis
- Nach Test: Problem besteht weiterhin, Timer wird nicht in allen Fällen zuverlässig gestoppt, UI bleibt manchmal hängen.
- Der Versuch war erfolglos.

# Fehlversuch 9 – Reset-Logik im Eltern-View (AtemView)

## Vorgehen
- Die Reset-Logik (`resetSession`) wurde aus dem Overlay (`SessionCard`) in den Eltern-View (`AtemView`) verlagert.
- Nach jedem Session-Ende, Abbruch oder Tab-Wechsel wird `runningPreset = nil` gesetzt und die Engine gestoppt.
- Das Overlay ruft die zentrale Reset-Funktion des Eltern-Views auf.

## Ergebnis
- Nach Test: Der Timer wird weiterhin nicht zuverlässig gestoppt, UI bleibt manchmal hängen.
- Das Problem ist nicht gelöst.

---

**Nächster Ansatz (in Arbeit):**
- Untersuche, ob die Timer-Engine (`SessionEngine`) nach `runningPreset = nil` wirklich gestoppt ist.
- Füge explizite Debug-Logs in die Timer-Engine ein, um alle Timer-Instanzen und deren Lebenszyklus zu überwachen.
- Prüfe, ob mehrere Instanzen von `SessionEngine` existieren und ob ein alter Timer weiterläuft, wenn ein neuer gestartet wird.
- Implementiere ggf. ein Singleton-Muster oder eine zentrale Timer-Instanz, die garantiert nur einen Timer zulässt.


---

**Fazit:**
Alle bisherigen Versuche waren entweder zu verteilt, nicht atomar oder haben das Problem nicht nachhaltig gelöst. Die nächste Strategie sollte eine zentrale, garantierte Reset-Logik für alle relevanten States und Tasks sein.
