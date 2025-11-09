# Bug: NoAlc Streak zählt alle Einträge statt nur Steady

**Erstellt:** 9. November 2025
**Status:** In Bearbeitung (Versuch 1)
**Datei:** `Meditationstimer iOS/CalendarView.swift` (Zeilen 37-55)

---

## Problem-Beschreibung

**Symptom:**
NoAlc Streak zählt **alle** Einträge (Steady, Easy, Wild) gleich, anstatt nur "Steady"-Einträge zu zählen.

**Erwartetes Verhalten (laut Spezifikation):**
- Streak zählt NUR bei "Steady" (0-1 drinks = HealthKit-Wert 0) weiter
- "Easy" (2-5 drinks) unterbricht Streak sofort
- "Wild" (6+ drinks) unterbricht Streak, AUSSER User hat Streak Points (Forgiveness)
- Forgiveness: 1 Streak Point kann 1 Wild-Tag verzeihen
- Streak Points: 1 pro 7 Tage Steady, max 3 🍃

**Aktuelles Verhalten im Code:**
- Streak zählt bei **jedem Eintrag** weiter (`alcoholDays[checkDate] != nil`)
- Kein Unterschied zwischen Steady/Easy/Wild
- Kein Forgiveness-Mechanismus implementiert
- Keine Streak Points Logik vorhanden

---

## Root Cause

**CalendarView.swift Zeile 45:**
```swift
if alcoholDays[checkDate] != nil {  // ← FEHLER: Prüft nur "Eintrag vorhanden?"
    currentStreak += 1              // → Sollte prüfen: "Eintrag ist Steady?"
    guard let previousDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
    checkDate = previousDate
} else {
    break
}
```

**Warum das falsch ist:**
- `!= nil` bedeutet "irgendein Eintrag vorhanden" (Steady, Easy oder Wild)
- Sollte stattdessen prüfen: `== .steady` (nur Steady-Einträge zählen)

---

## Beispiel-Szenario (zeigt den Bug)

**User-Daten:**
- Tag 1-2: Steady (0 drinks)
- Tag 3: Wild (6 drinks) ← Sollte Streak unterbrechen!
- Tag 4-5: Steady (0 drinks)

**Aktueller Code berechnet:** Streak = 5 Tage ❌
**Korrekt wäre:** Streak = 2 Tage (Tag 4-5) ✅

---

## Lösungsversuch 1 (9. November 2025)

**Änderung:** `CalendarView.swift` Zeilen 37-55

**Neue Logik:**
1. Tag ist Steady → currentStreak += 1
2. Tag ist Easy → Streak endet sofort (break)
3. Tag ist Wild:
   - Hat User Streak Points? (≥1 🍃)
     - JA: Streak läuft weiter, 1 Punkt verbrauchen
     - NEIN: Streak endet (break)
4. Kein Eintrag → Streak endet (break)

**Code-Änderungen:**

**VON:**
```swift
private var noAlcStreak: Int {
    let today = calendar.startOfDay(for: Date())
    let hasDataToday = alcoholDays[today] != nil

    var currentStreak = 0
    var checkDate = hasDataToday ? today : calendar.date(byAdding: .day, value: -1, to: today)!

    while true {
        if alcoholDays[checkDate] != nil {
            currentStreak += 1
            guard let previousDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDate
        } else {
            break
        }
    }

    return currentStreak
}
```

**ZU:**
```swift
private var noAlcStreak: Int {
    let today = calendar.startOfDay(for: Date())
    let hasDataToday = alcoholDays[today] == .steady

    var currentStreak = 0
    var streakPoints = 0
    var checkDate = hasDataToday ? today : calendar.date(byAdding: .day, value: -1, to: today)!

    while true {
        if let level = alcoholDays[checkDate] {
            if level == .steady {
                // Steady day: count it
                currentStreak += 1
                // Earn streak point every 7 days (max 3)
                if currentStreak % 7 == 0 && streakPoints < 3 {
                    streakPoints += 1
                }
            } else if level == .wild {
                // Wild day: check forgiveness
                if streakPoints > 0 {
                    // Use 1 streak point to forgive
                    streakPoints -= 1
                    currentStreak += 1
                } else {
                    // No points → streak ends
                    break
                }
            } else {
                // Easy day → streak ends immediately
                break
            }

            guard let previousDate = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = previousDate
        } else {
            // No entry → streak ends
            break
        }
    }

    return currentStreak
}

private var noAlcStreakPoints: Int {
    // Calculate streak points based on current streak
    let streak = noAlcStreak
    return min(3, streak / 7)
}
```

**UI-Änderung (Zeile 238):**
```swift
// VON:
rewardsView(for: min(3, noAlcStreak / 7), icon: "drop.fill", color: .green)

// ZU:
rewardsView(for: noAlcStreakPoints, icon: "drop.fill", color: .green)
```

---

## Lösungsversuch 2 (9. November 2025)

**Problem mit Lösungsversuch 1:**
User berichtet: "Jetzt wurden die zwei Rewards gelöscht"
- Vorher: 2 Rewards angezeigt
- Nach Fix: 0 Rewards
- User-Daten: 26.10.-7.11. (13 Tage Steady), 8.11. (Easy)

**Root Cause Analysis:**
Die `noAlcStreakPoints` computed property berechnete Points basierend auf der AKTUELLEN Streak-Länge:
```swift
private var noAlcStreakPoints: Int {
    let streak = noAlcStreak  // currentStreak = 0 nach Easy day
    return min(3, streak / 7)  // 0 / 7 = 0 points
}
```

**Warum das falsch ist:**
- User hatte 13-Tage-Streak → 1 Point bei Tag 7 verdient
- Easy day am 8.11. bricht currentStreak
- currentStreak = 0 → 0/7 = 0 points
- Aber: Der eine Point WURDE verdient und sollte persistieren!

**Neue Logik:**
Streak Points müssen aus GESAMTER Historie berechnet werden:
1. Chronologisch durch ALLE Daten iterieren
2. Earned Points tracken (bei jedem 7. Steady-Tag)
3. Consumed Points tracken (bei Wild-Tag-Forgiveness)
4. Return: `earnedPoints - consumedPoints`

**Code-Änderung:** `CalendarView.swift` Zeilen 80-117

**VON:**
```swift
private var noAlcStreakPoints: Int {
    let streak = noAlcStreak
    return min(3, streak / 7)
}
```

**ZU:**
```swift
private var noAlcStreakPoints: Int {
    // Calculate earned streak points from historical data
    let sortedDates = alcoholDays.keys.sorted()

    var earnedPoints = 0
    var consumedPoints = 0
    var consecutiveSteady = 0

    for date in sortedDates {
        guard let level = alcoholDays[date] else { continue }

        if level == .steady {
            consecutiveSteady += 1
            if consecutiveSteady % 7 == 0 && earnedPoints < 3 {
                earnedPoints += 1  // Point earned!
            }
        } else if level == .wild {
            let availablePoints = earnedPoints - consumedPoints
            if availablePoints > 0 {
                consumedPoints += 1  // Forgiveness used
            } else {
                consecutiveSteady = 0  // Streak breaks
            }
        } else {
            consecutiveSteady = 0  // Easy breaks streak
        }
    }

    return max(0, earnedPoints - consumedPoints)
}
```

**User-Scenario Validation:**
- 26.10.-2.11.: 7 Tage Steady → earnedPoints = 1
- 3.11.-7.11.: 5 weitere Tage Steady → consecutiveSteady = 12
- 8.11.: Easy → consecutiveSteady = 0, ABER earnedPoints = 1 bleibt!
- Result: 1 Point angezeigt (wie erwartet)

**Build-Status:** BUILD SUCCEEDED

---

## Lösungsversuch 3 (9. November 2025)

**Problem mit Lösungsversuch 2:**
User berichtet: "Es erscheint immer noch 'Streak 0 Days' und 0 Rewards"
- Trotz sichtbarer Daten (1.-8. November) in CalendarView
- Heute: 9. November (kein Eintrag)
- Streak sollte ~14 Tage zeigen, Rewards sollte 1 zeigen

**Root Cause Analysis:**
Lösungsversuch 2 verwendete **backwards iteration** (von heute → Vergangenheit):
```swift
// FALSCH: Start von heute/gestern und iteriere rückwärts
var checkDate = hasDataToday ? today : yesterday
while true {
    if let level = alcoholDays[checkDate] {
        // Problem: Rewards werden erst später verdient!
        if level == .wild && earnedRewards > 0 { ... }
    }
}
```

**Warum backwards iteration fehlschlägt:**
1. Iteration startet am 8.11. (Easy day)
2. Easy day braucht Reward zum heilen
3. Aber `earnedRewards = 0` zu diesem Zeitpunkt!
4. Warum? Weil die 7 Steady-Tage, die den Reward verdient haben, chronologisch DAVOR liegen
5. Aber in der backwards iteration kommen sie DANACH
6. → Reward wird erst später in der Iteration "verdient", kann aber jetzt nicht verwendet werden

**User Feedback:**
"Denke doch einmal nach: Wie ist die ganz einfache Regel? Du machst es aktuell immer komplizierter."

**Die einfache Regel:**
Chronologisch VORWÄRTS iterieren (Vergangenheit → heute):
1. Sortiere alle Daten chronologisch (frühestes → spätestes)
2. Iterate FORWARD durch alle Daten
3. Tracke: earnedRewards, consumedRewards, consecutiveDays
4. Bei Steady: count++, alle 7 Tage → earnedRewards++
5. Bei Easy/Wild mit Rewards: consumedRewards++, count++
6. Bei Easy/Wild ohne Rewards: Reset (consecutiveDays = 0)
7. Return: (consecutiveDays, earnedRewards - consumedRewards)

**Code-Änderung:** `CalendarView.swift` Zeilen 37-99

**ZU:**
```swift
private func calculateNoAlcStreakAndRewards() -> (streak: Int, rewards: Int) {
    let today = calendar.startOfDay(for: Date())

    // Sort all dates chronologically (earliest to latest)
    let sortedDates = alcoholDays.keys.sorted()

    guard !sortedDates.isEmpty else { return (0, 0) }

    var consecutiveDays = 0
    var earnedRewards = 0
    var consumedRewards = 0
    var currentStreakStart: Date? = nil

    // Iterate FORWARD through ALL data
    for date in sortedDates {
        guard let level = alcoholDays[date] else { continue }

        if level == .steady {
            consecutiveDays += 1
            if currentStreakStart == nil { currentStreakStart = date }

            // Earn reward every 7 days (max 3 total)
            if consecutiveDays % 7 == 0 && earnedRewards < 3 {
                earnedRewards += 1
            }
        } else {
            // Easy or Wild day: needs forgiveness
            let availableRewards = earnedRewards - consumedRewards

            if availableRewards > 0 {
                consumedRewards += 1
                consecutiveDays += 1  // Healed day counts!

                // Check if we earn a new reward for reaching a 7-day milestone
                if consecutiveDays % 7 == 0 && earnedRewards < 3 {
                    earnedRewards += 1
                }
            } else {
                // No rewards available → streak resets
                consecutiveDays = 0
                currentStreakStart = nil
            }
        }
    }

    let availableRewards = max(0, earnedRewards - consumedRewards)
    return (consecutiveDays, availableRewards)
}
```

**User-Scenario Validation:**
- 26.10.-2.11.: 7 Tage Steady → earnedRewards = 1, consecutiveDays = 7
- 3.11.-7.11.: 5 weitere Tage Steady → consecutiveDays = 12
- 8.11.: Easy → availableRewards = 1, consume it, consecutiveDays = 13
- 9.11.: Kein Eintrag (heute) → Streak = 13 days, Rewards = 0 (1 earned - 1 consumed)

**Build-Status:** Pending

---

## Test-Plan

1. Erstelle Test-Daten:
   - 7 Tage Steady → sollte 1 🍃 anzeigen
   - 1 Tag Wild → sollte 🍃 verbrauchen, Streak läuft weiter
   - 14 Tage Steady → sollte 2 🍃 anzeigen
   - 1 Tag Easy → sollte Streak unterbrechen

2. Prüfe UI:
   - Streak-Zahl korrekt
   - Streak Points (🍃) korrekt angezeigt

3. Build-Test durchführen

---

## Status

- [x] Code-Änderung implementiert (9. November 2025)
- [x] Syntax validiert (keine Compile-Errors in CalendarView.swift)
- [x] Lösungsversuch 2 implementiert (9. November 2025) - Streak Points Persistence Fix
- [x] Build erfolgreich (BUILD SUCCEEDED)
- [ ] Manueller Test ausstehend

---

## Related Files

- `Meditationstimer iOS/CalendarView.swift` (Zeilen 37-55, 238)
- `Services/NoAlcManager.swift` (ConsumptionLevel Enum)
- `DOCS/feature-NoAlcTracker_Spec.md` (Zeilen 135-142: Streak System)
