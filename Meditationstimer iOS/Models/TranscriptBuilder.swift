//
//  TranscriptBuilder.swift
//  Meditationstimer iOS
//
//  #57 Schnitt 3: Abschrift Fassung 1 fuer Claude (rein, ohne Versand, ohne Seiteneffekt).
//  Spec: DOCS/specs/features/feature-57-s3-abschrift.md (Regeln R1 bis R14)
//

import Foundation

/// Was das iPhone zeigt; `unreadable`, wenn ein gespeicherter Wert nicht lesbar war (R14).
struct TranscriptInput {
    var sets: [WorkoutSet] = []
    var presets: [AtemView.Preset] = []
    var claudeExercises: [ClaudeStoredExercise] = []
    var log: [ClaudeApplyLogEntry] = []
    var unreadable = false
}

enum TranscriptBuilder {
    private typealias Item = [String: Any]

    private static let claudeIdPattern = "^claude\\.[a-z0-9][a-z0-9-]{1,62}\\z"
    private static let anyIdPattern = "^(builtin|own|claude)\\.[a-z0-9][a-z0-9-]{1,62}\\z"
    private static let deliveryPattern = "^[A-Za-z0-9][A-Za-z0-9-]{7,63}\\z"

    // MARK: - Lesen (R14)

    static func readCurrent(defaults: UserDefaults) -> TranscriptInput {
        let sets = readList(ClaudeStore.setsKey, defaults, missing: defaultWorkoutSets) {
            WorkoutSet.migratingPresets($0, presets: defaultWorkoutSets)
        }
        let presets = readList(ClaudeStore.presetsKey, defaults, missing: MeditationTab.defaultPresets) {
            MeditationTab.migratingPresets($0)
        }
        let state = ClaudeStore.readState(from: defaults)
        return TranscriptInput(sets: sets.list, presets: presets.list, claudeExercises: state.state.exercises,
                               log: state.state.log, unreadable: sets.unreadable || presets.unreadable || state.unreadable)
    }

    private static func readList<T: Decodable>(_ key: String, _ defaults: UserDefaults, missing: [T],
                                               migrate: ([T]) -> [T]) -> (list: [T], unreadable: Bool) {
        guard let data = defaults.data(forKey: key) else { return (missing, false) }
        guard let stored = try? JSONDecoder().decode([T].self, from: data) else { return ([], true) }
        return (migrate(stored), false)
    }

    // MARK: - Bauen (R1)

    static func build(sets: [WorkoutSet], presets: [AtemView.Preset], claudeExercises: [ClaudeStoredExercise],
                      log: [ClaudeApplyLogEntry], now: Date) -> Data {
        let catalog = ExerciseDatabase.catalog.map {
            ["id": $0.id, "name": $0.name, "category": "\($0.category)", "origin": "builtin"] as Item
        }
        let claude = claudeExercises
            .sorted { ($0.claude.deliveredAt, $0.claude.itemId) < ($1.claude.deliveredAt, $1.claude.itemId) }
            .compactMap(claudeExercise)
        let root: Item = [
            "version": 1,
            "generatedAt": iso(now),
            "exercises": Array(unique(catalog + claude).prefix(500)),
            "programs": Array(unique(sets.compactMap(program)).prefix(200)),
            "breaths": Array(unique(presets.compactMap(breath)).prefix(200)),
            "deliveries": deliveries(log),
        ]
        let options: JSONSerialization.WritingOptions = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        let json = (try? JSONSerialization.data(withJSONObject: root, options: options)) ?? Data()
        return json + Data("\n".utf8)
    }

    // MARK: - Bausteine (R3 bis R7, R10)

    private static func claudeExercise(_ e: ClaudeStoredExercise) -> Item? {
        guard let name = clean(e.name, 40), let category = mapCategory(e.category),
              let effect = clean(e.effect, 600, lines: true), let how = clean(e.instructions, 1500, lines: true),
              var item = meta(e.id, e.claude, adapted: false) else { return nil }
        item.merge(compact(["name": name, "nameEn": clean(e.nameEn, 40), "category": "\(category)", "effect": effect,
                            "instructions": how, "notes": clean(e.notes, 600, lines: true)])) { $1 }
        return item
    }

    private static func program(_ s: WorkoutSet) -> Item? {
        let steps = Array(s.phases.compactMap(step).prefix(40))
        guard let name = clean(s.name, 40), validSymbol(s.emoji), !steps.isEmpty,
              var item = meta(s.id, s.claude, adapted: s.modifiedAt != nil) else { return nil }
        item.merge(compact(["name": name, "symbol": s.emoji, "description": clean(s.description, 500, lines: true),
                            "rounds": clamp(s.repetitions, 1, 99), "steps": steps])) { $1 }
        return item
    }

    private static func step(_ p: WorkoutPhase) -> Item? {
        guard let id = p.exerciseId?.lowercased(), matches(id, anyIdPattern) else { return nil }
        return compact(["exerciseId": id, "workSeconds": clamp(p.workDuration, 1, 600),
                        "restSeconds": clamp(p.restDuration, 0, 600), "hint": clean(p.hint, 80)])
    }

    private static func breath(_ p: AtemView.Preset) -> Item? {
        guard let name = clean(p.name, 40), validSymbol(p.emoji),
              var item = meta(p.id, p.claude, adapted: p.modifiedAt != nil) else { return nil }
        item.merge(compact(["name": name, "symbol": p.emoji, "description": clean(p.description, 500, lines: true),
                            "inhaleSeconds": clamp(p.inhale, 1, 60), "holdInSeconds": clamp(p.holdIn, 0, 60),
                            "exhaleSeconds": clamp(p.exhale, 1, 60), "holdOutSeconds": clamp(p.holdOut, 0, 60),
                            "rounds": clamp(p.repetitions, 1, 99)])) { $1 }
        return item
    }

    /// R6: Kennung und Herkunftsfelder; nil, wenn die Claude-Kennung ungueltig ist.
    private static func meta(_ id: UUID, _ c: ClaudeOrigin?, adapted: Bool) -> Item? {
        guard let c else { return ["id": "own." + id.uuidString.lowercased(), "origin": "own"] }
        guard matches(c.itemId, claudeIdPattern) else { return nil }
        let package = c.packageId.flatMap { matches($0, claudeIdPattern) ? $0 : nil }
        return compact(["id": c.itemId, "origin": "claude", "revision": clamp(c.revision, 1, 1_000_000),
                        "state": adapted ? "adapted" : "active", "packageId": package,
                        "packageName": clean(c.packageName, 40), "why": clean(c.why, 300),
                        "deliveredAt": iso(c.deliveredAt)])
    }

    // MARK: - Lieferergebnisse (R13)

    private static func deliveries(_ log: [ClaudeApplyLogEntry]) -> [Item] {
        var seen = Set<String>()
        let valid = log.filter { matches($0.deliveryId, deliveryPattern) && seen.insert($0.deliveryId).inserted }
        return valid.suffix(50).map { entry in
            var outcome = "accepted"
            if case .rejected = entry.result { outcome = "rejected" }
            return ["deliveryId": entry.deliveryId, "outcome": outcome]
        }
    }

    // MARK: - Hilfen (R2, R8, R9, R11)

    private static func compact(_ d: [String: Any?]) -> Item { d.compactMapValues { $0 } }

    private static func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { min(max(v, lo), hi) }

    private static func matches(_ s: String, _ pattern: String) -> Bool { s.range(of: pattern, options: .regularExpression) != nil }

    private static func unique(_ items: [Item]) -> [Item] {
        var seen = Set<String>()
        return items.filter { seen.insert($0["id"] as? String ?? "").inserted }
    }

    /// Ganze Sekunden (abgerundet), UTC, `Z`, unabhaengig von Zeitzone und Sprache.
    private static func iso(_ date: Date) -> String {
        Date.ISO8601FormatStyle().format(Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down)))
    }

    private static func forbidden(_ v: UInt32, lines: Bool) -> Bool {
        (v < 0x20 && !(lines && v == 0x0A)) || (0x7F...0x9F).contains(v) || v == 0x2028 || v == 0x2029
            || (0x202A...0x202E).contains(v) || (0x2066...0x2069).contains(v)
    }

    /// Erst bereinigen, dann auf `max` Unicode-Skalare kuerzen; nur Leerraum gilt als leer (nil).
    private static func clean(_ text: String?, _ max: Int, lines: Bool = false) -> String? {
        guard let text else { return nil }
        let kept = text.unicodeScalars.filter { !forbidden($0.value, lines: lines) }.prefix(max)
        guard kept.contains(where: { $0 != " " && $0 != "\u{A0}" && $0 != "\n" }) else { return nil }
        var view = String.UnicodeScalarView()
        view.append(contentsOf: kept)
        return String(view)
    }

    /// R10: Symbol unveraendert pruefen (1 bis 16 Skalare, keine verbotenen Zeichen, kein Leerraum, kein ASCII-Buchstabe oder -Ziffer).
    private static func validSymbol(_ s: String) -> Bool {
        let scalars = s.unicodeScalars
        return (1...16).contains(scalars.count) && !scalars.contains {
            forbidden($0.value, lines: false) || $0 == " " || $0.value == 0xA0
                || ($0.isASCII && (Character($0).isLetter || Character($0).isNumber))
        }
    }
}
