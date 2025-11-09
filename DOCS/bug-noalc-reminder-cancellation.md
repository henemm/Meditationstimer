# Bug: NoAlc Smart-Reminder erscheint trotz Logging

**Erstellt:** 9. November 2025
**Status:** Behoben (Versuch 3)
**Datei:** `Services/NoAlcManager.swift`

---

## Problem-Beschreibung

**Symptom:**
NoAlc-Eintrag wird um 22:00 Uhr protokolliert → Smart-Reminder erscheint trotzdem am nächsten Morgen

**Konfiguration:**
- Reminder-Bedingung: "in den letzten 16 Stunden kein Alkoholkonsum protokolliert"
- Erwartetes Verhalten: Reminder sollte nach Logging gecancelt werden

---

## Root Cause (identifiziert in Versuch 3)

**Problem:** `NoAlcManager.logConsumption()` übergibt `targetDay` (Mitternacht 00:00:00) statt der tatsächlichen Logging-Zeit an `cancelMatchingReminders()`.

**Konkrete Ursache:**
```swift
// NoAlcManager.swift Zeile 99
let targetDay = calendar.startOfDay(for: date)  // ← GESTERN 00:00:00

// Zeile 107
SmartReminderEngine.shared.cancelMatchingReminders(for: .noalc, completedAt: targetDay)
// ← Übergibt "gestern 00:00:00" statt "heute 22:00:00"
```

**Warum das fehlschlägt:**

1. User loggt um **22:00 Uhr**
2. System berechnet `targetDay` = **gestern 00:00:00**
3. `cancelMatchingReminders()` prüft Lookback-Fenster:
   - `nextTrigger` = **heute 09:00**
   - `lookBackStart` = **gestern 17:00** (09:00 - 16h)
   - `lookBackEnd` = **heute 09:00**
4. Prüfung: **gestern 00:00 >= gestern 17:00?** → **NEIN!**
5. Ergebnis: Reminder wird **NICHT gecancelt**

---

## Lösungsversuche

### Versuch 1 & 2
**Status:** Fehlgeschlagen (Details nicht dokumentiert)

### Versuch 3 (9. November 2025)
**Änderung:** `NoAlcManager.swift` Zeile 107

**VON:**
```swift
SmartReminderEngine.shared.cancelMatchingReminders(for: .noalc, completedAt: targetDay)
```

**ZU:**
```swift
SmartReminderEngine.shared.cancelMatchingReminders(for: .noalc, completedAt: Date())
```

**Begründung:**
Die Reverse Smart Reminders Logic benötigt die **tatsächliche Zeit des Loggings** (`Date()`), nicht den Tag für den geloggt wird (`targetDay`).

**Warum das funktioniert:**
- User loggt um 22:00 Uhr
- `Date()` = **22:00 Uhr** (aktuelle Zeit)
- Lookback-Fenster: **gestern 17:00 - heute 09:00**
- **22:00 >= 17:00?** → **JA!** (innerhalb des Fensters)
- Reminder wird gecancelt

---

## Test-Plan

1. NoAlc-Eintrag um 22:00 Uhr protokollieren
2. Smart-Reminder-Konfiguration prüfen (16h lookback)
3. Nächsten Morgen: Reminder sollte **NICHT** erscheinen
4. Logs prüfen: `✅ Cancelled reminder 'NoAlc Check-In'` sollte erscheinen

---

## Lessons Learned

1. **Trace complete data flow:** Nicht nur isolierte Code-Fragmente anschauen, sondern vollständigen Datenfluss analysieren (Entstehungsgeschichte)
2. **Date-Semantik wichtig:** `startOfDay(for:)` vs `Date()` haben unterschiedliche Bedeutungen - prüfen, welches die Logik benötigt
3. **Analysis-First:** Keine Quick Fixes ohne Root-Cause-Analyse
4. **Bug-Protokoll führen:** Zukünftig JEDEN Lösungsversuch dokumentieren (Lesson für Claude)

---

## Related Files

- `Services/NoAlcManager.swift` (Lines 94-109)
- `Meditationstimer iOS/SmartReminderEngine.swift` (Lines 134-185)
- `Services/HealthKitManager.swift` (Lines 748-752) - Ähnliche Logik, aber korrekt mit `normalizedDate`
