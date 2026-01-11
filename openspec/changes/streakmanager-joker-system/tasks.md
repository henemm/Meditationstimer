# Tasks: StreakManager Joker-System

## 1. StreakData Model erweitern

- [ ] `rewardsConsumed: Int` Property hinzufügen
- [ ] Computed Property `availableRewards` = `min(3, rewardsEarned - rewardsConsumed)`
- [ ] Codable-Kompatibilität sicherstellen (Migration für bestehende Daten)

## 2. Neue Methode `calculateStreakAndRewards()`

- [ ] Statische Methode erstellen (testbar ohne HealthKit)
- [ ] Signature: `static func calculateStreakAndRewards(dailyMinutes: [Date: Double], minMinutes: Int, calendar: Calendar) -> StreakResult`
- [ ] Forward Iteration implementieren (ältester Tag → heute)
- [ ] Über ALLE Tage iterieren (nicht nur Tage mit Daten)
- [ ] Gap-Erkennung: Tag ohne Daten = Fehltag
- [ ] "Heute nicht geloggt" tolerieren (kein Penalty)

## 3. Joker-Logik implementieren

- [ ] Alle 7 gute Tage: `rewardsEarned += 1` (max 3 on hand)
- [ ] Bei Fehltag mit Joker: `rewardsConsumed += 1`, Streak fortsetzt
- [ ] Bei Fehltag ohne Joker: Streak = 0, Rewards = 0
- [ ] "Earn before Consume" für Tag-7-Edge-Case

## 4. `updateStreak()` refactoren

- [ ] Alte backward-iteration Logik entfernen
- [ ] Neue `calculateStreakAndRewards()` aufrufen
- [ ] Ergebnis in StreakData speichern

## 5. Unit Tests schreiben

- [ ] Test: 7 Steady → Streak 7, 1 Joker
- [ ] Test: 6 Steady + 1 Gap → Streak 0 (kein Joker)
- [ ] Test: 7 Steady + 1 Gap → Streak 8, 0 Joker (geheilt)
- [ ] Test: 14 Steady + 2 Gaps → Streak 16, 0 Joker
- [ ] Test: 7 Steady + 2 Gaps → Streak 1 (nur letzter Tag, 2. Gap bricht)
- [ ] Test: Heute nicht geloggt → Streak zählt von gestern
- [ ] Test: Tag 7 ist Gap → Earn first, then consume
- [ ] Test: Max 3 Joker Cap

## Abhängigkeiten

- Keine externen Abhängigkeiten
- Referenz: `NoAlcManager.calculateStreakAndRewards()` für Pattern
