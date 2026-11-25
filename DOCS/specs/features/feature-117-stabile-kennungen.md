---
entity_id: feature-117-stabile-kennungen
type: feature
created: 2026-11-24
updated: 2026-11-24
status: draft
workflow: feature-117-stabile-kennungen
issue: 117
parent: claude-verbindung-app
---

# Stabile Kennungen für Vorgaben (#117)

## Approval

- [ ] Approved

Freigabe dieser Spec durch den PO.

## Purpose

Die 10 mitgelieferten Vorgaben (4 Programme, 6 Atemübungen) bekommen bei jedem App-Start neue Kennungen, weil ihre Initialisierer `UUID()` als Standardwert nutzen. Die Kennung `own.<uuid>` in der Abschrift an Claude (#57) gilt dadurch nur innerhalb eines Laufs; Claude könnte eine Vorgabe über zwei Starts hinweg nicht wiedererkennen. Jede Vorgabe bekommt deshalb eine feste, im Code eingetragene Kennung. Das muss vor #57 Schnitt 5 (Anmeldung) stehen. Sichtbar für Henning: nichts.

## Source

- Kontext und Analyse (maßgeblich): `DOCS/context/feature-117-stabile-kennungen.md`
- Herkunft: `DOCS/specs/features/feature-57-s3-abschrift.md` (R14), `DOCS/specs/features/feature-57-s4-abgleich.md` (Risiken, Folge-Issue #117)

## Ursache (belegt)

`defaultWorkoutSets` (`WorkoutTab.swift`, globales `let`) und `MeditationTab.defaultPresets` (`static let`) rufen die Initialisierer ohne `id:` auf. `WorkoutSet.init(id: UUID = UUID(), …)` und `AtemView.Preset.init(id: UUID = UUID(), …)` erzeugen daher je Prozess neue Kennungen. Betroffen ist jeder Fall, in dem eine Vorgabe aus dem Code statt aus dem Speicher kommt:

- (a) Schlüssel fehlt (`.missing`, nie gespeichert)
- (b) Schlüssel unlesbar (`.unreadable`)
- (c) gespeicherte Liste, an die `migratingPresets` eine fehlende Vorgabe nach Name anhängt

## Scope

App-Code (Grenze 250 Zeilen):

| Datei | Änderung | Inhalt | ca. Zeilen |
|---|---|---|---|
| `Meditationstimer iOS/Tabs/WorkoutTab.swift` | ändern | `defaultWorkoutSets`: je Programm `id: UUID(uuidString: "…")!` (4), Kommentar „Kennungen nie ändern“ | +6 |
| `Meditationstimer iOS/Tabs/MeditationTab.swift` | ändern | `defaultPresets`: je Atemübung `id: UUID(uuidString: "…")!` (6), Kommentar | +7 |

| `Meditationstimer iOS/Tabs/WorkoutProgramsView.swift` | ändern | `migratingPresets`: Anhängen nur, wenn weder Name noch Kennung vorhanden (AC-10) | ±1 |

`MeditationTab.migratingPresets` bekommt dieselbe Bedingung (±1 Zeile). Summe App-Code etwa 15 Zeilen. Nicht zum Budget:

| Datei | Änderung |
|---|---|
| `LeanHealthTimerTests/StableDefaultIdsTests.swift` | neu, XCTest, `@testable import Lean_Health_Timer`, deutsche `testXyz`-Namen |

Init-Signaturen (`WorkoutProgramsView.swift`, `AtemView.swift`) und das Codable-Format bleiben unverändert. Keine neuen AppStorage-Schlüssel, keine Berechtigungen, keine UI-Änderung, keine Änderung an Watch, Widget oder Kurzbefehlen (arbeiten über Namen), keine Gate-Konfiguration.

## Festgelegte Kennungen (Golden-Werte)

Kleinschreibung, gültiges Format, Version-4-Form, paarweise verschieden. Diese Werte dürfen nie geändert werden.

Programme (`defaultWorkoutSets`):

| Name | Kennung |
|---|---|
| Tabata Classic | `5a1e8c32-7b4d-4f19-9c60-2d3e8a41b701` |
| Core Circuit | `9f3b72d4-1c85-4a6e-b2f7-6e0d54c8a912` |
| Full Body Burn | `c47d09ab-e2f6-4358-8a1b-93b7f5d20c43` |
| Quick Burn | `2b86f1e7-04ca-4d92-a5e3-7c18d9b36f04` |

Atemübungen (`MeditationTab.defaultPresets`):

| Name | Kennung |
|---|---|
| Box Breathing | `e1d5a3c9-6f28-47b0-9d14-b5a07e8c2f65` |
| Calming Breath | `73c9b0f4-8a2e-4e61-bf05-1d6c4a97e836` |
| Coherent Breathing | `a8f24d61-3b97-4c0a-8e72-f40b6d1359c7` |
| Deep Calm | `0d6e9b35-c7a1-4f83-a248-8b9e31f5d078` |
| Relaxing Breath | `4f91c7e8-52d0-4b3a-9c86-a2e7d0481b59` |
| Rhythmic Breath | `b3a07f52-9e64-4d1c-85f9-3c5d82e6a41a` |

## Architektur-Entscheidung (ADR)

**ADR-Nr.:** keine (kleine, lokale Entscheidung; kippt keine bestehende ADR)

Feste UUID-Literale im Code. Deckt (a), (b) und (c) ab, ohne Seiteneffekt beim Laden; `TranscriptBuilder.readCurrent` bleibt rein. Gespeicherte Listen behalten ihre Kennungen, weil `id` aus dem JSON gelesen wird. Phasen-Kennungen (`WorkoutPhase.id`) bleiben zufällig; sie gehen nicht in die Abschrift ein (Schritte tragen nur `exerciseId`) und `ClaudeApply` baut Phasen neu.

Verworfene Alternativen:

- **Einmal beim ersten Start speichern:** Schreibzugriff im Ladepfad, ändert den Zustand `.missing`, auf den `ClaudeStore.apply` und die Abschrift sich verlassen; Fall (c) bei Programmen (Ergebnis wird nicht zurückgeschrieben) bliebe offen.
- **Kennung aus dem Namen ableiten (UUID v5/Hash, etwa 20 Zeilen, CryptoKit):** gleiche Wirkung, aber versteckter Mechanismus; eine Umbenennung der Vorgabe änderte die Kennung. Konstanten sind einfacher. Würde keine ADR kippen.

## Dependencies

| Abhängigkeit | Art | Hinweis |
|---|---|---|
| `WorkoutSet.init(id:…)`, `AtemView.Preset.init(id:…)` | Upstream | Signaturen und Codable-Format unverändert; `id` wird gespeichert |
| `ClaudeStore.loadSets` / `loadPresets`, `migratingPresets` | Downstream | Lesen Vorgaben bei `.missing`, `.unreadable` und beim Anhängen nach Name; unverändert |
| `TranscriptBuilder.readCurrent` / `build` | Downstream | Erzeugt `own.<uuid>`; unverändert |
| `ClaudeStore.apply` | Downstream | Schreibt bei `.missing` die Vorgaben, künftig mit festen Kennungen |
| #57 Schnitt 5 (Anmeldung) | Downstream | Darf erst nach diesem Ticket ausgeliefert werden |

## Expected Behavior

- Input: Die App liest Vorgaben aus dem Code (kein Schlüssel, Schlüssel unlesbar, oder Anhängen einer fehlenden Vorgabe durch `migratingPresets`).
- Output: Jede Vorgabe trägt ihre feste Kennung aus der Tabelle; die Abschrift zeigt `own.<kennung>` identisch über App-Starts.
- Side effects: `ClaudeStore.apply` schreibt bei `.missing` künftig die festen Kennungen in den Speicher. Gespeicherte Listen bleiben unverändert, auch Vorgaben darin mit zufälliger alter Kennung. Hat Henning eine Vorgabe aus seiner gespeicherten Liste gelöscht, hängt `migratingPresets` sie wie bisher wieder an, jetzt mit fester Kennung. Doppelte Kennungen sind ausgeschlossen: `migratingPresets` (Programme und Atemübungen) hängt eine Vorgabe nur an, wenn weder ihr Name noch ihre Kennung in der Liste vorkommt. Eine umbenannte Vorgabe zählt damit als vorhanden und wird nicht erneut angehängt (PO-Entscheidung 2026-11-24, aus Adversary-Befund F001).

## Acceptance Criteria

- **AC-1 (Golden, Programme):** Given der Code, When `defaultWorkoutSets` gelesen wird, Then tragen die 4 Programme (Name → Kennung) genau die Golden-Werte der Tabelle.
- **AC-2 (Golden, Atemübungen):** Given der Code, When `MeditationTab.defaultPresets` gelesen wird, Then tragen die 6 Atemübungen (Name → Kennung) genau die Golden-Werte der Tabelle.
- **AC-3 (verschieden):** Given alle 10 Kennungen, Then sind sie paarweise verschieden. Anzahl je Liste 4 bzw. 6 (kein stilles Hinzufügen ohne Golden-Wert).
- **AC-4 (Abschrift, Schlüssel fehlt):** Given Zustand `.missing` für Programme und Atemübungen, When `TranscriptBuilder` die Abschrift baut, Then steht für jede der 10 Vorgaben `own.<golden-uuid>`.
- **AC-5 (Abschrift, unlesbar):** Given Zustand `.unreadable`, When die Abschrift gebaut wird, Then steht für jede Vorgabe `own.<golden-uuid>`.
- **AC-6 (Abschrift, Anhängen):** Given eine gespeicherte Liste, der eine Vorgabe fehlt, und `migratingPresets` hängt sie an, When die Abschrift gebaut wird, Then steht für die angehängte Vorgabe `own.<golden-uuid>`.
- **AC-7 (gespeichert bleibt):** Given eine gespeicherte Liste mit zufälligen Kennungen (auch für Vorgaben mit Standardnamen), When sie geladen und in die Abschrift übernommen wird, Then bleiben diese Kennungen unverändert, nichts wird auf Golden-Werte umgeschrieben und es entsteht kein Duplikat.
- **AC-8 (apply bei .missing):** Given Zustand `.missing`, When `ClaudeStore.apply` etwas anwendet, Then enthält die geschriebene Liste die Vorgaben mit den Golden-Kennungen.
- **AC-10 (umbenannte Vorgabe):** Given eine gespeicherte Liste, in der eine Vorgabe ihre Golden-Kennung trägt, aber umbenannt ist (z. B. „Mein Burn“ mit der Kennung von „Quick Burn“), When `migratingPresets` (Programme bzw. Atemübungen) läuft, Then wird die Vorgabe mit dem Originalnamen nicht erneut angehängt, die Liste enthält jede Kennung genau einmal und die umbenannte Vorgabe bleibt unverändert.
- **AC-9 (Regression):** Alle bestehenden Unit-Tests (u. a. `ClaudeStoreTests`, `TranscriptBuilderTests`, `WorkoutPhaseMigrationTests`) bleiben grün.

## Test Plan

Datei `LeanHealthTimerTests/StableDefaultIdsTests.swift`, Unit-Tests (XCTest).

Nachweis „über zwei Starts gleich“: Ein `static let` wird je Prozess einmal ausgewertet; ein Vergleich im selben Prozess beweist nichts. Deshalb stehen die erwarteten UUIDs als String-Literale im Test. Jeder Testlauf ist ein neuer Prozess; eine Zufallskennung fiele sofort durch. Verglichen wird nur über `id`/`name`, nicht über `Equatable` des ganzen Programms (Phasen-Kennungen bleiben zufällig).

- [ ] Unit Test AC-1: Golden-Test 4 Programme (Name → Kennung)
- [ ] Unit Test AC-2: Golden-Test 6 Atemübungen (Name → Kennung)
- [ ] Unit Test AC-3: 10 Kennungen paarweise verschieden, Anzahl 4 und 6
- [ ] Unit Test AC-4/AC-5: Abschrift bei `.missing` und `.unreadable` zeigt `own.<golden>`
- [ ] Unit Test AC-6: gespeicherte Liste mit fehlender Vorgabe, Abschrift zeigt für die angehängte `own.<golden>`
- [ ] Unit Test AC-7: gespeicherte Liste mit zufälligen Kennungen bleibt unverändert, kein Duplikat
- [ ] Unit Test AC-8: `apply` bei `.missing` schreibt feste Kennungen
- [ ] Unit Test AC-10: umbenannte Vorgabe mit Golden-Kennung (je ein Programm und eine Atemübung) wird von `migratingPresets` nicht erneut angehängt, Kennungen eindeutig
- [ ] Bestehende Unit-Suite komplett grün (AC-9)
- UI-Test: nicht nötig. Es gibt keine sichtbare Änderung; Kennungen erscheinen nirgends in der Oberfläche, nur in der Abschrift, die Unit-Tests auf Datenebene prüfen. Die Abschrift selbst wird ohne Sitzung nicht gesendet (#57 S4).

Zusätzlich nach Implementierung der übliche Durchlauf der App im Simulator (Vorgabenlisten für Programme und Atemübungen öffnen, Zahl und Namen unverändert).

## Risiken und Restpunkte

- Kennungen müssen paarweise verschieden und dauerhaft unverändert sein; der Golden-Test hält sie fest, der Code-Kommentar warnt.
- Bereits gespeicherte Vorgaben behalten ihre damals zufällige Kennung (gespeichert, damit über Starts stabil). Umschreiben verstieße gegen „gespeicherte Listen unverändert“. Die Abschrift kann für denselben Namen daher bei verschiedenen Installationen verschiedene Kennungen tragen; für Claude zählt die Kennung innerhalb einer Installation.
- Ein Nutzer, der eine Vorgabe gelöscht hat, bekommt sie durch `migratingPresets` weiterhin zurück (bestehendes Verhalten, nicht Teil dieses Tickets).
- Keine offenen Fragen.

## Definition of Done

- [ ] AC-1 bis AC-10 nachgewiesen, im Protokoll `Executed N tests` mit N ≥ 1
- [ ] Vollständige Unit-Suite und UI-Suite grün
- [ ] Build grün für iOS (Simulator `iPhone 17 Pro`, iOS 27.2), Watch und Widget
- [ ] Produktiv-Diff nur in `WorkoutTab.swift`, `MeditationTab.swift` und `WorkoutProgramsView.swift`, ≤ 250 Zeilen
- [ ] Durchlauf im Simulator: Programm- und Atemliste zeigen dieselben Vorgaben wie vorher, mit Screenshot
- [ ] Adversary-Prüfung: Verdict VERIFIED

## Changelog

- 2026-11-24: Initial spec created
- 2026-11-24: Adversary-Befund F001 (doppelte Kennung nach Umbenennen einer Vorgabe): PO entscheidet „umbenannte Vorgabe zählt als vorhanden“; AC-10, `migratingPresets` prüft Name und Kennung, Scope um `WorkoutProgramsView.swift` erweitert
- 2026-11-24: Abschnitte Dependencies, Definition of Done und ADR-Zeile nach Validierung ergänzt
