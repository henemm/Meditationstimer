//
//  ClaudeDelivery.swift
//  Meditationstimer
//
//  Lese-Modell fuer Lieferungen von Claude (Format hhhaven.delivery/1), #51 Schnitt 1.
//  Reines Lesen: kein Mapping auf App-Typen, keine Speicherung. Nur Foundation.
//

import Foundation

struct ClaudePackage: Equatable { let packageId: String; let name: String }

struct ClaudeExercise: Equatable {
    let itemId: String; let revision: Int; let name: String; let nameEn: String?
    let category: String; let effect: String; let instructions: String; let notes: String?
}

struct ClaudeProgramStep: Equatable {
    let exerciseId: String; let workSeconds: Int; let restSeconds: Int; let hint: String?
}

struct ClaudeProgram: Equatable {
    let itemId: String; let revision: Int; let name: String; let symbol: String
    let description: String?; let rounds: Int; let steps: [ClaudeProgramStep]
}

struct ClaudeBreath: Equatable {
    let itemId: String; let revision: Int; let name: String; let symbol: String
    let description: String?
    let inhaleSeconds: Int; let holdInSeconds: Int; let exhaleSeconds: Int; let holdOutSeconds: Int
    let rounds: Int
}

struct ClaudeWithdrawal: Equatable { let itemId: String?; let packageId: String? }

enum ClaudeItem: Equatable {
    case exercise(ClaudeExercise)
    case program(ClaudeProgram)
    case breath(ClaudeBreath)
    case withdrawal(ClaudeWithdrawal)
    case unsupported(kind: String)
}

struct ClaudeDeliveryError: Error, Equatable {
    let code: String
    let reason: String
}

struct ClaudeDelivery: Equatable {
    let format: String
    let deliveryId: String
    let source: String
    let createdAt: Date
    let why: String
    let package: ClaudePackage?
    let items: [ClaudeItem]

    /// Liest Rohdaten. Ist alles lesbar und kommt reminder/challenge/tracker vor, lehnt die ganze Lieferung ab.
    static func read(_ data: Data) throws(ClaudeDeliveryError) -> ClaudeDelivery {
        guard let any = try? JSONSerialization.jsonObject(with: data), let root = any as? [String: Any] else {
            throw cannotRead("Die Datei ist kein lesbares JSON.")
        }
        var items: [ClaudeItem] = []
        for entry in try Field.array(root, "items") {
            items.append(try readItem(try Field.object(entry, "items")))
        }
        var package: ClaudePackage?
        if let rawPackage = root["package"] {
            let p = try Field.object(rawPackage, "package")
            package = ClaudePackage(packageId: try Field.string(p, "packageId"), name: try Field.string(p, "name"))
        }
        let delivery = ClaudeDelivery(
            format: try Field.string(root, "format"),
            deliveryId: try Field.string(root, "deliveryId"),
            source: try Field.string(root, "source"),
            createdAt: try readDate(try Field.string(root, "createdAt")),
            why: try Field.string(root, "why"),
            package: package, items: items)
        for case .unsupported(let kind) in items {
            throw ClaudeDeliveryError(code: "KIND_NOT_SUPPORTED",
                                      reason: "Die Art \"\(kind)\" kann die App noch nicht annehmen.")
        }
        return delivery
    }

    fileprivate static func cannotRead(_ reason: String) -> ClaudeDeliveryError {
        ClaudeDeliveryError(code: "APP_CANNOT_READ", reason: reason)
    }

    private static func readDate(_ text: String) throws(ClaudeDeliveryError) -> Date {
        let formatter = ISO8601DateFormatter()
        for options: ISO8601DateFormatter.Options in [[.withInternetDateTime, .withFractionalSeconds], [.withInternetDateTime]] {
            formatter.formatOptions = options
            if let date = formatter.date(from: text) { return date }
        }
        throw cannotRead("Das Erstellungsdatum ist nicht lesbar.")
    }

    private static func readItem(_ r: [String: Any]) throws(ClaudeDeliveryError) -> ClaudeItem {
        let kind = try Field.string(r, "kind")
        switch kind {
        case "exercise":
            return .exercise(ClaudeExercise(
                itemId: try Field.string(r, "itemId"), revision: try Field.int(r, "revision"),
                name: try Field.string(r, "name"), nameEn: r["nameEn"] as? String,
                category: try Field.string(r, "category"), effect: try Field.string(r, "effect"),
                instructions: try Field.string(r, "instructions"), notes: r["notes"] as? String))
        case "program":
            var steps: [ClaudeProgramStep] = []
            for entry in try Field.array(r, "steps") {
                let o = try Field.object(entry, "steps")
                steps.append(ClaudeProgramStep(
                    exerciseId: try Field.string(o, "exerciseId"),
                    workSeconds: try Field.int(o, "workSeconds"), restSeconds: try Field.int(o, "restSeconds"),
                    hint: o["hint"] as? String))
            }
            return .program(ClaudeProgram(
                itemId: try Field.string(r, "itemId"), revision: try Field.int(r, "revision"),
                name: try Field.string(r, "name"), symbol: try Field.string(r, "symbol"),
                description: r["description"] as? String, rounds: try Field.int(r, "rounds"), steps: steps))
        case "breath":
            return .breath(ClaudeBreath(
                itemId: try Field.string(r, "itemId"), revision: try Field.int(r, "revision"),
                name: try Field.string(r, "name"), symbol: try Field.string(r, "symbol"),
                description: r["description"] as? String,
                inhaleSeconds: try Field.int(r, "inhaleSeconds"), holdInSeconds: try Field.int(r, "holdInSeconds"),
                exhaleSeconds: try Field.int(r, "exhaleSeconds"), holdOutSeconds: try Field.int(r, "holdOutSeconds"),
                rounds: try Field.int(r, "rounds")))
        case "withdrawal":
            return .withdrawal(ClaudeWithdrawal(itemId: r["itemId"] as? String, packageId: r["packageId"] as? String))
        case "reminder", "challenge", "tracker":
            return .unsupported(kind: kind)
        default:
            throw cannotRead("Unbekannte Art \"\(kind)\" in der Lieferung.")
        }
    }

    /// Feldzugriffe; jeder Fehler ist APP_CANNOT_READ mit deutschem Grund.
    private enum Field {
        static func string(_ o: [String: Any], _ key: String) throws(ClaudeDeliveryError) -> String {
            guard let v = o[key] as? String else {
                throw ClaudeDelivery.cannotRead("Pflichtfeld \"\(key)\" fehlt oder ist kein Text.")
            }
            return v
        }

        /// Ganze Zahlen auch in der Schreibweise 30.0.
        static func int(_ o: [String: Any], _ key: String) throws(ClaudeDeliveryError) -> Int {
            guard let n = o[key] as? NSNumber, n.doubleValue == n.doubleValue.rounded() else {
                throw ClaudeDelivery.cannotRead("Pflichtfeld \"\(key)\" fehlt oder ist keine ganze Zahl.")
            }
            return n.intValue
        }

        static func array(_ o: [String: Any], _ key: String) throws(ClaudeDeliveryError) -> [Any] {
            guard let v = o[key] as? [Any] else {
                throw ClaudeDelivery.cannotRead("Pflichtfeld \"\(key)\" fehlt oder ist keine Liste.")
            }
            return v
        }

        static func object(_ v: Any, _ key: String) throws(ClaudeDeliveryError) -> [String: Any] {
            guard let o = v as? [String: Any] else {
                throw ClaudeDelivery.cannotRead("Eintrag in \"\(key)\" ist kein Objekt.")
            }
            return o
        }
    }
}
