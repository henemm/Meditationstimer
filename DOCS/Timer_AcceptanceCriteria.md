# Timer Reparatur – Akzeptanzkriterien & Erkenntnisse


## Ziel
- Robuste, einheitliche Timer-Logik für alle Meditationstabs (Atem, Workouts, Offen)
- Der äußere Ring zeigt immer die Gesamtdauer der Session
- "Beenden" stoppt den Timer und entfernt die Live Activity im Widget garantiert
- Es darf immer nur eine Live Activity/Timer im Widget erscheinen
- UI bleibt konsistent und nachvollziehbar
- Die GUI darf nicht verändert werden (kein Layout-, Button-, oder Flow-Change)
- Jede Codeübergabe ist build-validiert

## Erfolgreiche Ansätze
- Portierung der robusten Timer- und EndSession-Logik aus WorkoutsView nach AtemView
- Entfernen von GongPlayer.stopAll() aus SessionCard, stattdessen engine.cancel() verwenden
- Entfernen des automatischen Session-Starts im Idle-State, stattdessen expliziter Start-Button
- Dual-Ring-UI im Idle-State wiederhergestellt
- Build-Fehler durch falsche CircularRing-Parameter behoben


 Erneuter Versuch mit stopAllSounds()-Methode, Build erfolgreich, aber nicht gewünscht – wurde wieder entfernt
- Entfernen des automatischen Timer-Starts im Atem-Tab (.idle-State): GUI zerstört, Änderung rückgängig gemacht
- Wiederholtes automatisches Starten der Session im Idle-State nach "Beenden" (Live Activity Bug)
- Falsche Parameter für CircularRing (Build-Fehler)
- Rücksetzung auf letzten Commit: Timer läuft nach "Beenden" weiterhin weiter, Problem besteht trotz Rücksetzung und Build-Validierung

## Offene Probleme
- Timer im Atem-Tab muss nach "Beenden" garantiert gestoppt sein und die Live Activity entfernt werden
- Widget darf nie zwei Timer gleichzeitig anzeigen
- UI muss nach "Beenden" in den konsistenten Idle-State zurückkehren

## Nächste Schritte
1. Projekt auf letzten stabilen Commit zurücksetzen
2. Timer-Reparatur ab stabilem Stand neu beginnen
3. Erkenntnisse aus dieser Datei und den letzten Debug-Sitzungen berücksichtigen
4. Nach jedem Schritt Build validieren
5. Akzeptanzkriterien laufend aktualisieren

---
Letzte Aktualisierung: 18.10.2025
