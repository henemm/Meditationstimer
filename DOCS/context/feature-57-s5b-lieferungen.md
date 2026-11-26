# Context: feature-57-s5b-lieferungen (#57 Schnitt 5b)

## Request Summary
Schnitt 5b der Claude-Verbindung: Auf der bestehenden Seite „Claude-Verbindung“ (Schnitt 5a, PR #120) zwei Abschnitte
ergänzen: Liste der letzten Lieferungen samt Ergebnis und „Was Claude sieht“ als kurzer Klartext.
Elternspec `openspec/specs/features/claude-verbindung-app.md` Verhalten 4 (:28) und Schnitt 5b (:67); Konzept Abschnitt 7
(`DOCS/konzept-claude-verbindung.md:181-190`) und :207.

Vorgänger: Workflow `feature-57-s5-einstellungen` phase8_complete, PR #120 gemergt (Übernahme der Registrierung begründet).

## Related Files
| File | Relevance |
|------|-----------|
| `Meditationstimer iOS/Claude/ClaudeSettingsView.swift` (136 Z.) | Seite. Angemeldet: Section (a) Status + „Letzter Abgleich“ (:48-53), Section (b) Abmelden/Trennen (:54-64). Neue Abschnitte zwischen :53 und :54. Aktualisierung nur `.onAppear` (:21) und `.onChange(of: account.status)` (:22). Kennungen `claudeSettings.*`. |
| `Meditationstimer iOS/Models/ClaudeApply.swift` | `ClaudeApplyLogEntry { deliveryId, result, at }` (:26-30) — **kein Titel, keine Art, kein Paket**. `ClaudeApplyResult` `.applied / .noEffect / .rejected(code:reason:)` (:20-24), Grund als deutscher Text. Log: neueste zuletzt, ≤ 50, keine Doppel (:48, :54-56, :75-76). `ClaudeOrigin` (:11-18) trägt `packageName`, aber keine `deliveryId`. |
| `Meditationstimer iOS/Models/ClaudeStore.swift` | `readState(from:) -> (state, unreadable)` (:86-90), rein. `.claudeStoreDidChange` (:12) nur bei geschriebenen Listen, nicht bei Ablehnung/noEffect. |
| `Meditationstimer iOS/Models/TranscriptBuilder.swift` | `readCurrent(defaults:) -> TranscriptInput { sets, presets, claudeExercises, log, unreadable }` (:12-18, :29). Abschrift: exercises (Katalog + Claude, ≤ 500), programs (≤ 200), breaths (≤ 200), deliveries (≤ 50; noEffect → accepted) (:58-65, :120-128). Klartext muss aus `TranscriptInput` entstehen. |
| `Meditationstimer iOS/Meditationstimer_iOSApp.swift` | DEBUG-Hook `uitest-claude-apply` + `UITEST_CLAUDE_DELIVERY` (:109-130): eine Lieferung je Start, Zustand bleibt über Starts erhalten. |
| `LeanHealthTimerUITests/ClaudeEinstellungenUITests.swift` (257 Z.) | Vorbild: `launch(extra)`, `openClaudePage()` (:90-97), Anmelden über `signInStandIn` (:108-117). |
| `Meditationstimer iOS/Localizable.xcstrings` | Claude-Schlüssel vorhanden (Seite 5a); für Lieferliste/„Was Claude sieht“ noch keine. |

## Existing Patterns
- Seite liest Zustand beim Erscheinen und bei Statuswechsel, ohne Notification (Muster „Letzter Abgleich“).
- Kennungen `claudeSettings.<name>`; Texte `NSLocalizedString`, DE primär, EN-Schlüssel.
- Reine Funktionen für Anzeige-Texte mit Unit-Test (Schnitt 5a: Zeit-Text).
- UI-Test-Zustände über Startargumente, nur DEBUG.

## Dependencies
- Upstream: `ClaudeStore.readState`, `TranscriptBuilder.readCurrent`, `ClaudeApplyLogEntry`.
- Downstream: Abschrift (`deliveries`) liest das Log — eine Erweiterung des Log-Eintrags darf das Abschrift-Format nicht ändern.

## Existing Specs
- `openspec/specs/features/claude-verbindung-app.md` (Eltern)
- `docs/specs/features/feature-57-s5-einstellungen.md` (5a, :27 nennt 5b-Umfang)
- `docs/specs/features/feature-57-s3-abschrift.md` (Abschrift Fassung 1, :40 was nicht übertragen wird)

## Risks & Considerations
- **Log-Einträge haben keinen Titel.** Eine Liste nur aus Datum + Ergebnis sagt nicht, *was* geliefert wurde. Für Titel
  müsste `ClaudeApplyLogEntry` optionale Felder bekommen (Codable abwärtskompatibel, alte Einträge ohne Titel).
- Abgelehnte Lieferungen hinterlassen keinen Baustein → Titel nur aus der Lieferung selbst beim Anwenden ableitbar.
- Keine Notification bei Ablehnung → Liste aktualisiert sich nur beim Öffnen der Seite (reicht: Abgleich läuft beim Start/Vordergrund).
- UI-Test: mehrere Log-Einträge nur über mehrere Starts ohne Zurücksetzen oder einen neuen DEBUG-Hook.
- Abschrift-Format darf sich nicht ändern (Dienst prüft Schema `transcript-v1`).
- Sichtbare Änderung → Entwurf vor Spec (`docs/artifacts/feature-57-s5b-lieferungen/`).

## Analysis

### Type
Feature (#57 Schnitt 5b, Teil von Epic #44)

### Recherche
Keine neue Schnittstelle: `Form`/`Section`/`LabeledContent`, `Date.formatted(.relative)` bzw. `.dateTime` sind seit iOS 15/16
Standard und in 5a schon im Einsatz. Keine Modellnutzung — „Was Claude sieht“ ist Zählen + fester Satz (Regelweg).

### Ansatz (Empfehlung)
1. **Lieferliste** (Abschnitt „Letzte Lieferungen“): neueste zuerst, höchstens 10 sichtbar; je Zeile Titel (falls bekannt),
   Datum, Ergebnis „Übernommen“ / „Ohne Änderung“ / „Abgelehnt“ (+ Grund in Grau). Leer: „Noch keine Lieferungen“.
   Titel: `ClaudeApplyLogEntry` bekommt optional `title` und `kind` (beim Anwenden aus der Lieferung gesetzt);
   Abschrift unverändert (nur deliveryId/outcome).
2. **„Was Claude sieht“**: reine Funktion aus `TranscriptInput` → zwei Absätze:
   „Claude sieht: 42 Übungen (davon 3 von Claude), 6 Programme, 4 Atemübungen und die letzten 12 Lieferergebnisse.“
   „Claude sieht nicht: Tracker-Einträge wie Alkohol, Stimmung und Dankbarkeit, Daten aus Apple Health, Notizen.“
3. Beide Abschnitte nur angemeldet, zwischen Status und Aktionen.

### Alternativen
- **B: Liste ohne Titel** (nur Datum + Ergebnis): keine Änderung am Log, ~25 Zeilen weniger, aber Henning sieht nicht, was kam.
- **C: Lieferliste als eigene Unterseite** („Lieferungen ›“ mit Anzahl): Seite bleibt kurz, ein Tipp mehr.
- „Was Claude sieht“ als aufklappbarer Abschnitt statt dauerhaft sichtbar.

### Affected Files
| File | Change |
|------|--------|
| `Meditationstimer iOS/Claude/ClaudeSettingsView.swift` | MODIFY: zwei Sections |
| `Meditationstimer iOS/Claude/ClaudeSeesText.swift` (o. ä.) | CREATE: reine Funktionen Klartext + Ergebnis-Text |
| `Meditationstimer iOS/Models/ClaudeApply.swift` | MODIFY: optionale Felder title/kind im Log (nur Variante A) |
| `Meditationstimer iOS/Localizable.xcstrings` | Texte DE/EN |
| Tests: Unit (Klartext, Log-Titel, Abschrift unverändert), UI (Liste mit angenommen + abgelehnt, „Was Claude sieht“) | |

### Scope
~100–120 Zeilen App-Code (A), 3 Swift-Dateien + xcstrings. Innerhalb der Grenzen. Risiko niedrig (Seite nur bei Schalter an).

### Entwurf
`DOCS/artifacts/feature-57-s5b-lieferungen/index.html`, veröffentlicht: https://claude.ai/artifact/LzfbS7khgAeteLdSHJ3jc4
(Heute-Screenshot dunkel, Entwurf dunkel/hell mit Liste + „Was Claude sieht“, Alternative C Unterseite, Sonderfall leer.)

### Open Questions
- [ ] PO: Entwurf freigeben — Empfehlung: Liste direkt auf der Seite (10 neueste) mit Titel (Log um Art/Name erweitert).
