# Countdown-Sync Projekt

## Ziel
Die Countdown-Anzeige (Ring) und die LiveActivity sollen immer exakt dieselbe Restzeit anzeigen. Die Endzeit/Phasen für LiveActivity dürfen nicht aus separater Logik/Objekten stammen, sondern müssen direkt aus der Ring-Logik kommen.

## Schritt 1: Kontext & Codequellen identifizieren

### Vorgehen
- Untersuche, wie und wo die Endzeit/Phasen an LiveActivity übergeben werden.
- Prüfe, ob die Quelle identisch mit der Ring-Anzeige ist.
- Dokumentiere alle Erkenntnisse und Codepfade.

### Status
Abgeschlossen. Erkenntnisse:

#### OffenView (Meditation)
- Endzeit für LiveActivity wird beim Start lokal berechnet und übergeben (jetzt + Phase1).
- Die Ring-Anzeige verwendet die Engine, die dieselbe Endzeit berechnet und speichert.
- Endzeit wird an zwei Stellen berechnet: einmal für LiveActivity, einmal für die Engine.

#### AtemView (Atem)
- Endzeit für LiveActivity wird beim Start aus SessionCard berechnet und übergeben.
- Die Ring-Anzeige verwendet die Engine, die die Phasen und Restzeit steuert.
- Auch hier wird die Endzeit separat berechnet und übergeben.

#### WorkoutsView (Workout)
- Ring-Anzeige berechnet Restzeit aus sessionStart und sessionTotal.
- LiveActivity-Integration ist aktuell entfernt/auskommentiert.
- Endzeit für die Session ist: sessionStart + sessionTotal.

#### LiveActivityController
- Erwartet Endzeit und Phase als Parameter beim Start.
- Endzeit kommt aus dem jeweiligen Tab, nicht direkt aus der Engine/Ring-Logik.

**Fazit Schritt 1:**
In allen Tabs wird die Endzeit für die LiveActivity separat berechnet und übergeben, meist direkt beim Start. Die Ring-Anzeige verwendet die Engine, die die Endzeit ebenfalls berechnet und speichert. Es gibt also eine doppelte Berechnung, was zu Abweichungen führen kann, falls die Logik nicht exakt synchron ist.

## Weitere Schritte
Werden nach Abschluss von Schritt 1 ergänzt.

---
Jeder Schritt wird hier dokumentiert und ist nachvollziehbar überprüfbar.