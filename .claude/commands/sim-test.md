# Simulator UI Tests durchfuehren

## ⛔ DIESER BEFEHL IST PFLICHT!

**XCUITests MÜSSEN vor JEDER Validierung laufen!**

---

## Wann ausführen?

| Situation | XCUITest Pflicht? |
|-----------|-------------------|
| Nach Implementation | ✅ JA |
| Vor `/4-validate` | ✅ JA |
| Vor Device-Test für Henning | ✅ JA |
| Bei UI-Änderungen | ✅ JA |
| Bei Workflow-Änderungen (Timer, Workout) | ✅ JA |

**NIEMALS dem User etwas zum manuellen Testen geben OHNE vorher XCUITests auszuführen!**

---

## XCUITest Befehl

```bash
xcodebuild test \
  -project Meditationstimer.xcodeproj \
  -scheme "Lean Health Timer" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:LeanHealthTimerUITests \
  2>&1 | grep -E "(Test Case|passed|failed|error:)"
```

---

## Was XCUITests testen MÜSSEN

Für jedes Feature/Fix muss ein XCUITest existieren der:
1. **Den Anwendungsfall simuliert** (so nah wie möglich am echten Nutzer)
2. **Die erwartete UI verifiziert** (Elemente existieren, richtige Position)
3. **Den Workflow durchläuft** (Start → Aktion → Ende)

**Beispiel für "Round X of Y" Feature:**
- Workout Tab öffnen
- Free Workout konfigurieren (3 Runden)
- Start drücken
- Warten bis Rest-Phase
- Verifizieren dass UI korrekt aktualisiert

---

## Bei FAIL

❌ **NICHT zum User gehen!**
❌ **NICHT Device-Test-Anweisungen geben!**

✅ Erst fixen, dann erneut testen!

---

## Device-Test ist NUR für

- Voice/TTS Ausgabe (kann Simulator nicht)
- Haptic Feedback (kann Simulator nicht)
- HealthKit echte Daten
- Watch Connectivity
