# AC-21 Start-Nachweis, #51 Runde 2a-1

**Ergebnis: BESTANDEN**

- Datum: 2026-11-20. Lauf alter Stand ab 20:24:35Z, Lauf neuer Stand ab 20:26:47Z.
- Alter Stand: `origin/main` dbdef2e590da61c8c1a34de18f0ef25e31aea723 (Merge PR #104, zugleich Merge-Basis des Arbeitszweigs).
  Der lokale Zeiger `main` (496722d, 2026-09-22) ist veraltet und wurde nach einem ersten Lauf verworfen, siehe unten.
- Neuer Stand: Worktree `starry-nibbling-patterson`, HEAD 9e398f06fb65e2ee2a768eaf93b36efb81264fa3 plus die uncommitteten Dateien
  `ClaudeApply.swift` (neu), `WorkoutProgramsView.swift` und `AtemView.swift` (byte-gleich per `cmp` in die Scratch-Kopie übernommen).
- Simulator: iPhone 17 Pro, iOS 27.2, per Name+OS aufgelöst (UDID 9892DDA6-6C8E-4EF7-8C8E-59F2AB5BE34B).
- Bundle-ID laut Build (`Info.plist`): **henemm.Meditationstimer-iOS**. Die Spec nennt `henemm.Meditationstimer.dev2`. Diese ID gehört
  laut Projektdatei zu einem anderen Ziel (Watch-Umfeld), nicht zur iOS-App. Verwendet wurde deshalb `henemm.Meditationstimer-iOS` und
  `Library/Preferences/henemm.Meditationstimer-iOS.plist`. Die Spec sollte korrigiert werden.

## Ablauf

1. Scratch-Kopie von `origin/main` (`git archive`) plus Wegwerf-Test `AC21WegwerfUITests` (hier als `.swift.txt` beigelegt).
   Der Test ist in beiden Kopien identisch und läuft ohne `enable-testing`, also mit echten UserDefaults.
   Er startet die App, zeichnet Workout-Tab und Atem-Bereich auf (Screenshot und Texte der Bedienhilfe-Ansicht), öffnet dann das erste
   Programm im Editor und tippt auf Speichern, danach dasselbe mit der ersten Atemübung.
2. `xcodebuild build-for-testing`, danach `simctl uninstall` (geprüft: App nicht mehr installiert). Anschließend
   `xcodebuild test-without-building -parallel-testing-enabled NO -only-testing:LeanHealthTimerUITests/AC21WegwerfUITests/testAC21`.
   Ergebnis: Executed 1 test, 0 failures.
3. Die plist aus dem App-Container kopiert. Mit `plutil -extract … raw`, Base64-Dekodierung und `jq -S` entstanden `vorher-*.json`.
   Kein Backup-Schlüssel vorhanden.
4. Neuen Stand gebaut und mit `simctl install` **ohne Deinstallation** darüber installiert. Der Datencontainer wird dabei verschoben (neue UUID).
   Die plist danach ist **byte-gleich** mit der vorher gesicherten (`cmp`).
5. Derselbe Wegwerf-Test lief auf dem neuen Stand (Executed 1 test, 0 failures): erst Screenshots und Texte, dann dasselbe erste Programm
   und dieselbe erste Atemübung im Editor gespeichert.
6. Erneut gesichert: `nachher-*.json` mit `jq -S 'map(del(.claude, .modifiedAt))'`, die ungefilterte Fassung liegt als `nachher-*.voll.json` bei.

## Befunde

| | vorher (main) | nachher (neu) |
|---|---|---|
| workoutProgramSets | 4: Tabata Classic, Core Circuit, Full Body Burn, Quick Burn | 4, gleich |
| atemPresets | 6: Box Breathing, Calming Breath, Coherent Breathing, Deep Calm, Relaxing Breath, Rhythmic Breath | 6, gleich |

- `diff-workoutProgramSets.txt` und `diff-atemPresets.txt` sind leer (0 Byte). Damit sind Anzahl, Namen und alle Felder gleich, auch alle `id`s.
  Die `id`s sind zufällig (`UUID()` in den Vorgaben). Hätte der neue Stand die Daten nicht gelesen oder hätte die erneute Installation durch
  xcodebuild sie gelöscht, wären beim Speichern Vorgaben mit neuen `id`s geschrieben worden, und der Vergleich wäre fehlgeschlagen.
- Auch ohne das Entfernen von `claude` und `modifiedAt` sind die Dateien identisch: Die neuen Felder werden bei `nil` nicht geschrieben.
- Kein Schlüssel `workoutProgramSetsBackup.*` (plist enthält nur `atemPresets` und `workoutProgramSets`).
- Bildschirm: `diff-screen-workout.txt` und `diff-screen-atem.txt` sind leer. Die Bedienhilfe-Texte (alle 4 bzw. 6 Namen, 4 bzw. 6 Bearbeiten-Knöpfe)
  sind vor und nach dem Update gleich. Die Screenshots zeigen sichtbar nur den Kopf der Liste mit dem ersten Eintrag
  (Tabata Classic bzw. Box Breathing), gleich vor und nach dem Update. Die übrigen Namen belegen die `.txt`-Dateien.

## Verworfener Erstlauf (lokaler, veralteter `main` 496722d)

Der erste Durchgang lief versehentlich mit dem lokalen `main` vom 2026-09-22, der noch vor #48 liegt. Dort war der Programm-Diff nicht leer:
Der neue Stand ergänzt in jedem Schritt `exerciseId` (Migration aus #48, A2b-0). Das ist erwartetes Verhalten aus #48 und hat mit 2a-1 nichts zu tun.
Der Atem-Diff war auch dort leer. Mit dem gültigen Ausgangsstand `origin/main` wurde der Durchgang komplett wiederholt (oben).
