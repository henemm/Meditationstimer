# Adversary Dialog — feature-117-stabile-kennungen
Spec: DOCS/specs/features/feature-117-stabile-kennungen.md
Datum: 2026-11-24 22:01

## Checkliste
- [x] Input: Die App liest Vorgaben aus dem Code (kein Schlüssel, Schlüssel unlesbar, oder Anhängen einer fehlenden Vorgabe durch `migratingPresets`).
- [x] Output: Jede Vorgabe trägt ihre feste Kennung aus der Tabelle; die Abschrift zeigt `own.<kennung>` identisch über App-Starts.
- [x] Side effects: `ClaudeStore.apply` schreibt bei `.missing` künftig die festen Kennungen in den Speicher. Gespeicherte Listen bleiben unverändert, auch Vorgaben darin mit zufälliger alter Kennung. Hat Henning eine Vorgabe aus seiner gespeicherten Liste gelöscht, hängt `migratingPresets` sie wie bisher wieder an, jetzt mit fester Kennung. Doppelte Kennungen sind ausgeschlossen, weil nur angehängt wird, wenn der Name fehlt.
- [x] **AC-1 (Golden, Programme):** Given der Code, When `defaultWorkoutSets` gelesen wird, Then tragen die 4 Programme (Name → Kennung) genau die Golden-Werte der Tabelle.
- [x] **AC-2 (Golden, Atemübungen):** Given der Code, When `MeditationTab.defaultPresets` gelesen wird, Then tragen die 6 Atemübungen (Name → Kennung) genau die Golden-Werte der Tabelle.
- [x] **AC-3 (verschieden):** Given alle 10 Kennungen, Then sind sie paarweise verschieden. Anzahl je Liste 4 bzw. 6 (kein stilles Hinzufügen ohne Golden-Wert).
- [x] **AC-4 (Abschrift, Schlüssel fehlt):** Given Zustand `.missing` für Programme und Atemübungen, When `TranscriptBuilder` die Abschrift baut, Then steht für jede der 10 Vorgaben `own.<golden-uuid>`.
- [x] **AC-5 (Abschrift, unlesbar):** Given Zustand `.unreadable`, When die Abschrift gebaut wird, Then steht für jede Vorgabe `own.<golden-uuid>`.
- [x] **AC-6 (Abschrift, Anhängen):** Given eine gespeicherte Liste, der eine Vorgabe fehlt, und `migratingPresets` hängt sie an, When die Abschrift gebaut wird, Then steht für die angehängte Vorgabe `own.<golden-uuid>`.
- [x] **AC-7 (gespeichert bleibt):** Given eine gespeicherte Liste mit zufälligen Kennungen (auch für Vorgaben mit Standardnamen), When sie geladen und in die Abschrift übernommen wird, Then bleiben diese Kennungen unverändert, nichts wird auf Golden-Werte umgeschrieben und es entsteht kein Duplikat.
- [x] **AC-8 (apply bei .missing):** Given Zustand `.missing`, When `ClaudeStore.apply` etwas anwendet, Then enthält die geschriebene Liste die Vorgaben mit den Golden-Kennungen.
- [x] **AC-9 (Regression):** Alle bestehenden Unit-Tests (u. a. `ClaudeStoreTests`, `TranscriptBuilderTests`, `WorkoutPhaseMigrationTests`) bleiben grün.

## Dialog

### Runde 1
**Adversary:** Alle 12 Punkte geprüft. Skript-Abgleich Spec-Tabelle gegen Code: 10/10 Name->Kennung identisch, Kleinschreibung, gültiges Format, paarweise verschieden (WorkoutTab.swift:800-850, MeditationTab.swift:70-83). Lesepfade ClaudeStore.swift:63-75 und TranscriptBuilder.swift:30-34 nutzen dieselben Vorgaben-Objekte. Keine weitere Zufallsquelle für Vorgaben: WorkoutTab.swift:104 und MeditationTab.swift:134 sind Neu-Karten, ClaudeApply.swift:147/162 Claude-Einträge; Watch/Widget ohne Kopie; Kurzbefehle über Namen. Diff nur in zwei Dateien (+12/-6), Signaturen und Codable unverändert. Unit-Suite: Executed 457 tests, 0 failures, StableDefaultIdsTests 8/8 passed.
**Implementierer:** keine Rückmeldung, Prüfer arbeitet read-only.

### Runde 2
**Adversary:** Nachgebohrt an zwei in Runde 1 nur behaupteten Stellen.
(1) Anhängepfad Programme: WorkoutProgramsView.swift:352-356 hängt nur an, wenn der NAME fehlt; das Ergebnis wird von ClaudeStore.loadSets (ClaudeStore.swift:67) zurückgegeben und von der UI zurückgeschrieben (WorkoutTab.swift:368 ff., für Atemübungen MeditationTab.swift:469-476 mit savePresets() bei stored != presets). Eine feste Kennung kann also neben einer alten gespeichert landen. Die Spec-Behauptung "Doppelte Kennungen sind ausgeschlossen, weil nur angehängt wird, wenn der Name fehlt" gilt nur bei Namensprüfung, nicht bei Kennungsprüfung.
(2) ClaudeStore.apply bei .missing liest direkt (ClaudeStore.swift:63 und :71, aufgerufen aus :117), nicht über migratingPresets; geschrieben wird new.sets/new.presets (:126-127). BEWIESEN, AC-8 korrekt.
Neues Szenario (F001): .missing -> Vorgaben werden mit Golden-Kennungen gespeichert (apply :126 oder UI-Speichern). Henning benennt "Quick Burn" in "Mein Burn" um (Kennung 2b86f1e7-... bleibt, id kommt aus JSON). Beim nächsten Laden fehlt der Name "Quick Burn" -> migratingPresets (WorkoutProgramsView.swift:354-355) hängt die Vorgabe mit derselben Kennung an -> zwei Einträge mit gleicher id in der Liste, UI schreibt sie zurück. Vorher (Zufalls-ID je Prozess) war das ausgeschlossen. Folgen: ForEach(sets) (WorkoutTab.swift:92) / ForEach(presets) (MeditationTab.swift:122) mit doppelter id, Abschrift mit zwei gleichen own.<kennung>, Claude-Abgleich nach id mehrdeutig. Gleiches für alle 6 Atemübungen (MeditationTab.swift:487). Kein Test deckt das ab (AC-7 testet nur Zufallskennungen).
Testlog (nicht neu gestartet): Executed 457 tests, with 0 failures, TEST SUCCEEDED, StableDefaultIdsTests 8/8.
**Implementierer:** Antwort steht aus; Empfehlung: migratingPresets haengt nur an, wenn weder Name noch id vorhanden sind (oder Spec-Entscheidung, dass Umbenennen einer Vorgabe als geloescht gilt und neue id bekommt), plus Test.

## Herkunft der Vorbedingungen

Spec-Tabelle (Golden-Werte) und Code im Worktree; keine Vorbedingung aus fremden Berichten.

## Verdict

**BROKEN**

### Befunde

- F001 | severity MEDIUM | category edge_case | Umbenannte Standardvorgabe mit fester Kennung wird von migratingPresets erneut mit derselben Kennung angehängt, Duplikat-id in gespeicherter Liste (Spec-Aussage "Doppelte Kennungen ausgeschlossen" widerlegt).
  Code reference: Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:354
  Code reference: Meditationstimer iOS/Tabs/MeditationTab.swift:487
  Remediation: nur anhängen, wenn weder Name noch id existieren; Test ergänzen.

## Geprüfte Dateien

- sha256:82a4a03db0c664c87a62b14bf75e9da344770c7d5ba36c8c9b106f8161cdfe93  Meditationstimer iOS/Tabs/MeditationTab.swift
- sha256:0d33f20bb17cf309c12ce5bb125a66f34eb839a77978a2ac518b4f1dca5275b8  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift

## Prüfbasis

- base: 0ffbaa12df8172b3462e6751952b092d74ddf761
- blob:dad1c1ab651117dee381b6fc25a3874fe4477485  Meditationstimer iOS/Tabs/MeditationTab.swift
- blob:ba2942ebf72435a8e8a4db717e73bb96f51e9090  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift

## Geprüfte Dateien

- sha256:82a4a03db0c664c87a62b14bf75e9da344770c7d5ba36c8c9b106f8161cdfe93  Meditationstimer iOS/Tabs/MeditationTab.swift
- sha256:0d33f20bb17cf309c12ce5bb125a66f34eb839a77978a2ac518b4f1dca5275b8  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift

## Prüfbasis

- base: 0ffbaa12df8172b3462e6751952b092d74ddf761
- blob:dad1c1ab651117dee381b6fc25a3874fe4477485  Meditationstimer iOS/Tabs/MeditationTab.swift
- blob:ba2942ebf72435a8e8a4db717e73bb96f51e9090  Meditationstimer iOS/Tabs/WorkoutProgramsView.swift
