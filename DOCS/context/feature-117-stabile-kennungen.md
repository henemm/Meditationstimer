# Context: feature-117-stabile-kennungen

## Request Summary
Die mitgelieferten Vorgaben (4 Programme, 6 Atemübungen) bekommen bei jedem App-Start eine neue UUID. Ihre Kennung
`own.<uuid>` in der Abschrift an Claude (#57) ist dadurch nur innerhalb eines Laufs stabil. Ziel: Kennung jeder
Vorgabe über App-Starts gleich, bestehende gespeicherte Listen unverändert. Muss vor #57 Schnitt 5 (Anmeldung) stehen.

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Tabs/WorkoutTab.swift:800–857` | `let defaultWorkoutSets` (4 Programme: Tabata Classic, Core Circuit, Full Body Burn, Quick Burn), jeweils `WorkoutSet(name:…)` ohne `id:` → `UUID()` beim ersten Zugriff je Prozess |
| `Meditationstimer iOS/Tabs/MeditationTab.swift:70–83` | `static let defaultPresets` (6 Atemübungen), `.init(name:…)` ohne `id:` |
| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift:176` | `WorkoutSet.init(id: UUID = UUID(), …)` |
| `Meditationstimer iOS/Tabs/AtemView.swift:56` | `AtemView.Preset.init(id: UUID = UUID(), …)` |
| `Meditationstimer iOS/Models/ClaudeStore.swift:62–77` | `loadSets`/`loadPresets`: ohne gespeicherten Schlüssel → Vorgaben (`.missing`); gespeichert → `migratingPresets` hängt fehlende Vorgaben **nach Name** an |
| `Meditationstimer iOS/Models/TranscriptBuilder.swift:107–110` | `meta`: ohne Claude-Herkunft → `"own." + id.uuidString.lowercased()` |
| `Meditationstimer iOS/Tabs/WorkoutTab.swift:367`, `MeditationTab.swift:467` | UI-Laden; Atem speichert nach Migration zurück, wenn sich etwas geändert hat |

## Existing Patterns
- Vorgaben sind Code-Konstanten (globales `let` bzw. `static let`); `static let` wird einmal je Prozess ausgewertet → innerhalb eines Laufs stabil, über Starts nicht.
- Migration fehlender Vorgaben erfolgt nach **Name**, nicht nach Kennung (`WorkoutSet.migratingPresets`, `MeditationTab.migratingPresets`).
- Phasen-Kennungen (`WorkoutPhase.id`) gehen nicht in die Abschrift (Schritte tragen nur `exerciseId`) → nur Kennungen von Programm und Atemübung betroffen.

## Dependencies
- Upstream: `WorkoutSet`, `AtemView.Preset` (Codable, `id` wird mitgespeichert).
- Downstream: `TranscriptBuilder.readCurrent/build` (Abschrift), `ClaudeStore.loadSets/loadPresets` (Zustand für `apply`), UI-Listen (Identifiable).

## Existing Specs
- `DOCS/specs/features/feature-57-s3-abschrift.md` R14 (Problem benannt)
- `DOCS/specs/features/feature-57-s4-abgleich.md` Risiken (bewusst nicht gelöst, Folge-Issue #117)

## Analyse (Summe 2: Kontext und Analyse in einem Durchgang)

**Ursache (belegt):** `defaultWorkoutSets` und `MeditationTab.defaultPresets` rufen die Initialisierer ohne `id:` auf;
der Standardwert `UUID()` erzeugt bei jedem Prozessstart neue Kennungen. Betroffen sind alle Fälle, in denen eine
Vorgabe aus dem Code (nicht aus dem Speicher) kommt: (a) Schlüssel fehlt (nie gespeichert), (b) Schlüssel unlesbar,
(c) gespeicherte Liste, an die `migratingPresets` eine fehlende Vorgabe nach Name anhängt (bei Programmen wird das
Ergebnis nicht zurückgeschrieben).

**Empfehlung: feste Kennungen im Code.** Jede der 10 Vorgaben bekommt eine feste, im Code eingetragene UUID
(`id: UUID(uuidString: "…")!`). Deckt (a), (b) und (c) ab, ohne Seiteneffekt beim Laden; `readCurrent` bleibt rein.
Bereits gespeicherte Listen behalten ihre (zufälligen, aber dort schon stabilen) Kennungen, weil `id` aus dem JSON gelesen
wird. Umfang: 2 App-Dateien, ~10 geänderte Zeilen, plus Unit-Tests.

**Alternative 1: einmal beim ersten Start speichern.** Verworfen: Schreibzugriff im Ladepfad, ändert den Zustand
`.missing`, auf den `ClaudeStore.apply` und die Abschrift sich verlassen; Fall (c) bei Programmen bliebe offen.
**Alternative 2: Kennung aus dem Namen ableiten (Hash).** Gleiche Wirkung wie feste Konstanten, aber versteckter
Mechanismus; eine Umbenennung der Vorgabe änderte die Kennung. Konstanten sind einfacher.

## Risks & Considerations
- Kennungen müssen paarweise verschieden sein (10 Stück) und dürfen nie geändert werden → Unit-Test auf Eindeutigkeit und Festwert.
- Nutzer mit gespeicherter Liste, aus der er eine Vorgabe gelöscht hat: `migratingPresets` hängt sie (bestehendes Verhalten) wieder an, jetzt mit fester Kennung — keine Verhaltensänderung sonst.
- Duplikat-Gefahr: Ein gespeichertes Element mit zufälliger Kennung und die angehängte Vorgabe haben nie dieselbe Kennung (Anhängen nur, wenn der Name fehlt).
- Keine neuen AppStorage-Schlüssel, keine Berechtigungen, keine UI-Änderung.

## Analysis

### Type
Feature (technische Vorbedingung für #57 Schnitt 5)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `Meditationstimer iOS/Tabs/WorkoutTab.swift` | MODIFY | `defaultWorkoutSets`: je Programm `id: UUID(uuidString: "…")!` (4 Zeilen), Kommentar „Kennungen nie ändern“ |
| `Meditationstimer iOS/Tabs/MeditationTab.swift` | MODIFY | `defaultPresets`: je Atemübung `id:` vor `name:` (6 Zeilen), Kommentar |
| `LeanHealthTimerTests/` (neue Datei oder ClaudeStoreTests) | CREATE/MODIFY | Golden-Test Name → feste UUID (10), paarweise verschieden, Abschrift-Ebene `own.<golden>` für `.missing`, `.unreadable`, gespeicherte Liste mit fehlender Vorgabe |

Init-Signaturen (`WorkoutProgramsView.swift:176`, `AtemView.swift:56`) und Codable-Format bleiben unverändert. Keine Kopien
der Vorgaben in Watch, Widget oder Kurzbefehlen (`ShortcutHandler`/`ShortcutModels` arbeiten über Namen).

### Scope Assessment
- Files: 2 App-Dateien + 1 Testdatei
- Estimated LoC: App ~+12/-0 (Argumente + Kommentar), Tests ~+50
- Risk Level: LOW

### Technical Approach
Feste UUID-Literale für die 10 Vorgaben (Begründung und verworfene Alternativen siehe Abschnitt „Analyse“ oben).
Strategische Bewertung (Plan/Sonnet, 2026-11-24) bestätigt: deckt Fälle (a) Schlüssel fehlt, (b) unlesbar, (c) Anhängen
per `migratingPresets` ab, weil alle drei Wege `defaultWorkoutSets`/`defaultPresets` nutzen (`ClaudeStore.swift:63–75`,
`TranscriptBuilder.swift:30–34`). `ClaudeStore.apply` bei `.missing` schreibt künftig die festen Kennungen in den Speicher.
Bestehende Tests (`ClaudeStoreTests` 139–149, 365–398; `WorkoutPhaseMigrationTests` 380–407) bleiben gültig.

**Testnachweis „über zwei Starts gleich“:** Ein `static let` wird je Prozess einmal ausgewertet, ein Vergleich im selben
Prozess beweist nichts. Daher Golden-Test: erwartete UUIDs als String-Literale im Test; jeder Testlauf ist ein neuer
Prozess, eine Zufallskennung fiele sofort durch. Zusätzlich auf Abschrift-Ebene `own.<golden-uuid>` prüfen.
Vergleich nur über `id`/`name`, nicht `Equatable` des ganzen Programms (Phasen-Kennungen bleiben zufällig, gehen aber
nicht in Abschrift oder `apply` ein — `ClaudeApply.swift:137–148` baut Phasen neu).

**Alternative:** Kennung aus Namen ableiten (UUID v5, CryptoKit, ~20 LoC) — keine Literale, aber Umbenennung ändert die
Kennung; einfacher Weg ist die Konstante.

### Dependencies
`WorkoutSet`, `AtemView.Preset` (Codable, `id` gespeichert) → `ClaudeStore.loadSets/loadPresets`, `TranscriptBuilder`,
`migratingPresets` (Abgleich nach Name, unverändert).

### Restpunkte (kein Handlungsbedarf)
- Bereits gespeicherte Vorgaben behalten ihre damals zufällige Kennung; die ist gespeichert und damit über Starts stabil.
  Umschreiben würde gegen „gespeicherte Listen unverändert“ verstoßen.
- Die festen Kennungen dürfen nie geändert werden (Kommentar im Code, Golden-Test hält sie fest).

### Open Questions
- keine
