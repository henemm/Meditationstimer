# Adversary-Dialog feature-51-s2a3-ruecknahme (#51, Runde 2a-3)

**Verdict: VERIFIED** · 2026-11-21 · Prüfer: implementation-validator (sah nur Spec, Vertrag, betroffene Datei und Tests)

## Runde 1: Tests, Checkliste, Edge Cases

### Testlauf
- Unit-Suite `LeanHealthTimerTests`, seriell: `Executed 309 tests, with 0 failures (0 unexpected)`, `** TEST SUCCEEDED **`.
- Alle 10 neuen Tests der Runde `passed`.
- Watch ("Meditationstimer Watch App") und Widget ("MeditationstimerWidgetExtension"): BUILD SUCCEEDED (Developer-Lauf, gleicher Stand; Adversary hat sie nicht erneut gebaut, Datei ist reines Foundation).

### Checkliste-Befunde Runde 1
- [x] AC-2: Alle lesbaren Beispiele angewendet, nie `rejected`; Mindestanzahl 51/32 erzwungen (`ClaudeApplyTests.swift:719-752`).
- [x] AC-8b: 6 Fälle × 2 Arten, blockiert bei `modified > snapshot` und `snapshot == nil`, entfernt bei `nil`, Gleichheit (Grenze) und `<` (`:755-782`; Code `ClaudeApply.swift:180-181`).
- [x] AC-9: einzeln, Vereinigung bei beiden Kennungen, `noEffect` bei unbekannter bzw. fehlender Kennung, `claude == nil` nie getroffen (`:785-846`; `hit()` `:172-175`).
- [x] AC-10: Paket komplett entfernt, Rest bleibt; `package-with-withdrawal.json` ergibt `ruecken-a2`; geänderter Paket-Baustein sperrt ganze Lieferung ohne Teilentfernung (`:862-914`; Treffermenge → Sperrprüfung → `removeAll`).
- [x] AC-11: Übung entfernt auch bei `lastSnapshotAt == nil`, Programmphasen unverändert (`:917-931`).
- [x] AC-17: Round-Trip aller drei Ergebnisse und Zustand mit `rejected`-Logeintrag (`:934-949`).
- [x] AC-18: nur Foundation, kein `UserDefaults`/`NotificationCenter`/`Date()` (`:952-966`); Diff seit Rundenbeginn nur Kontext, Spec, Briefing, Tests, `ClaudeApply.swift`, Doku `claude-annahme.md`; keine Änderung an `WorkoutTab.swift`, `MeditationTab.swift`, `ExerciseDatabase.swift`, `project.pbxproj`.
- [x] AC-19: Suite grün, Produktiv-Diff +20/−0, `applyWithdrawal` 17 Zeilen, `apply` ~26; iOS, Watch, Widget bauen.

### Edge Cases (Code-Lektüre, alle sicher)
- Mehrere Positionen: Arbeitskopie `work`, Rücknahme sieht frühere Anlagen derselben Lieferung.
- Ablehnung einer Position: `break`, `work` wird nicht übernommen, ganz oder gar nicht lieferungsweit.
- Gedächtnis: bekannte `deliveryId` liefert gemerktes Ergebnis (Regel 5, Bestand).
- Duplikat-Kennungen: `filter`/`removeAll` konsistent.
- Leere Strings: treffen nur gelieferte Bausteine mit leerer Kennung; eigene unberührt.

### Findings Runde 1
- Niedrig (Hinweis): beide Kennungen gesetzt → Vereinigung, wie in Präzisierung 4 spezifiziert; `read` prüft `WITHDRAWAL_TARGET` nicht (bewusst außerhalb dieser Runde).

## Runde 2: Nachfragen zu offenen Punkten

**Nachfrage 1 — Watch/Widget-Build selbst belegen:** Prüfer hat beide Ziele seriell gebaut.
- "Meditationstimer Watch App" (generic/platform=watchOS Simulator): BUILD SUCCEEDED (`ClaudeApply.swift` gehört nicht zum Watch-Ziel; Runde bricht dort nichts).
- "MeditationstimerWidgetExtension" (generic/platform=iOS Simulator): BUILD SUCCEEDED, `ClaudeApply.swift` kompiliert mit.
- Bewertung: AKZEPTIERT, AC-19 Build aller drei Ziele belegt.

**Nachfrage 2 — vertragswidrige Rücknahmen (`invalid/withdrawal-both.json`, `withdrawal-none.json`):**
- `read` (`ClaudeDelivery.swift:129-130`) nimmt beide an; dokumentiert und außerhalb dieser Runde (Präzisierung 4, ADR verworfene Alternative).
- `apply`: keine Kennung → `noEffect`; beide → Vereinigung. Definiert, kein Absturz, wörtlich Präzisierung 4; belegt durch `testRuecknahmeUnbekannterKennungOhneWirkung` und `testRuecknahmeEinzelnEntferntBaustein` (grün).
- Hinweis (kein Defekt): Die zwei Vertragsdateien selbst laufen durch keinen Test; der Fall wird von Hand gebaut. Leere Strings treffen nur gelieferte Bausteine mit leerer Kennung.
- Bewertung: AKZEPTIERT.

**Nachfrage 3 — Doku-DoD `openspec/specs/features/claude-annahme.md`:** Schnitt 2 in 2a (erledigt) / 2b (offen) geteilt, Verweis auf Elternspec im Kopf und in Schnitt 2, Abweichung Übungen in `claudeState` in Verhalten 2; deckt sich mit dem Code. Bewertung: AKZEPTIERT.

## Checkliste (Abschluss nach Runde 2)
- [x] AC-2: Alle lesbaren Beispiele angewendet, nie `rejected`; Mindestanzahl 51/32 erzwungen (`ClaudeApplyTests.swift:719-752`).
- [x] AC-8b: 6 Fälle × 2 Arten, blockiert bei `modified > snapshot` und `snapshot == nil`, entfernt bei `nil`, Gleichheit (Grenze) und `<` (`:755-782`; Code `ClaudeApply.swift:180-181`).
- [x] AC-9: einzeln, Vereinigung bei beiden Kennungen, `noEffect` bei unbekannter bzw. fehlender Kennung, `claude == nil` nie getroffen (`:785-846`; `hit()` `:172-175`).
- [x] AC-10: Paket komplett entfernt, Rest bleibt; `package-with-withdrawal.json` ergibt `ruecken-a2`; geänderter Paket-Baustein sperrt ganze Lieferung ohne Teilentfernung (`:862-914`; Treffermenge → Sperrprüfung → `removeAll`).
- [x] AC-11: Übung entfernt auch bei `lastSnapshotAt == nil`, Programmphasen unverändert (`:917-931`).
- [x] AC-17: Round-Trip aller drei Ergebnisse und Zustand mit `rejected`-Logeintrag (`:934-949`).
- [x] AC-18: nur Foundation, kein `UserDefaults`/`NotificationCenter`/`Date()` (`:952-966`); Diff seit Rundenbeginn nur Kontext, Spec, Briefing, Tests, `ClaudeApply.swift`, Doku `claude-annahme.md`; keine Änderung an `WorkoutTab.swift`, `MeditationTab.swift`, `ExerciseDatabase.swift`, `project.pbxproj`.
- [x] AC-19: Suite grün, Produktiv-Diff +20/−0, `applyWithdrawal` 17 Zeilen, `apply` ~26; iOS, Watch, Widget bauen.

## Verdict

**VERIFIED** — keine Findings mit Schwere Hoch/Mittel; Hinweise: Vereinigung bei beiden Kennungen (spezifiziert), Vertragsdateien `invalid/withdrawal-*` nicht als Test durch read+apply.

## Geprüfte Dateien

- sha256:80b3017a019f544ebcb882e61b106df8bd2d6432ec7c7c565c4c8b1a7a48408d  LeanHealthTimerTests/ClaudeApplyTests.swift
- sha256:537e36a2cc31984a350aaf79b925fc7e6837dd0d77a50e31f482379628efa421  Meditationstimer iOS/Models/ClaudeApply.swift
- sha256:f80c9cf527acb38dd98734cefe47d511d084c39d3d793f8adaf0879832d41cef  openspec/specs/features/claude-annahme.md

## Prüfbasis

Spec `DOCS/specs/features/feature-51-s2a3-ruecknahme.md`, Elternspec `DOCS/specs/features/feature-51-s2-bausteine-anwenden.md`, Vertrag §3.4; Unit-Suite 309/309 (Runde 1), Builds Watch und Widget (Runde 2).
