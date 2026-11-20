//
//  ClaudeDeliveryDecodingTests.swift
//  LeanHealthTimerTests
//
//  TDD RED #51 Schnitt 1: Lese-Modell fuer Lieferungen von Claude.
//  Oberflaeche laut docs/artifacts/feature-51-lieferung-annehmen/test-api-vertrag.md.
//  Es wird nur Contracts/deliveries/valid/ gelesen (AC-11).
//

import XCTest
@testable import Lean_Health_Timer

final class ClaudeDeliveryDecodingTests: XCTestCase {

    // MARK: - Hilfen

    private typealias Json = [String: Any]
    private struct Sample { let name: String; let delivery: Json }

    private static let unsupportedKinds: Set<String> = ["reminder", "challenge", "tracker"]

    private func testDir(_ file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)").deletingLastPathComponent()
    }

    private func loadSamples(file: StaticString = #filePath) throws -> [Sample] {
        let dir = testDir(file).appendingPathComponent("../Contracts/deliveries/valid").standardized
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasSuffix(".json") }.sorted()
        return try names.map { name in
            let data = try Data(contentsOf: dir.appendingPathComponent(name))
            let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? Json, name)
            let delivery = try XCTUnwrap(root["delivery"] as? Json, "\(name): delivery fehlt")
            return Sample(name: name, delivery: delivery)
        }
    }

    private func bytes(_ json: Json) throws -> Data {
        try JSONSerialization.data(withJSONObject: json)
    }

    private func items(_ json: Json) -> [Json] { json["items"] as? [Json] ?? [] }

    private func isUnsupported(_ json: Json) -> Bool {
        items(json).contains { Self.unsupportedKinds.contains($0["kind"] as? String ?? "") }
    }

    private func int(_ value: Any?) -> Int? { (value as? NSNumber)?.intValue }

    private func iso(_ text: String, millis: Bool) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = millis ? [.withInternetDateTime, .withFractionalSeconds] : [.withInternetDateTime]
        return f.date(from: text)
    }

    private func sample(_ name: String) throws -> Sample {
        try XCTUnwrap(try loadSamples().first { $0.name == name }, "\(name) fehlt")
    }

    // MARK: - AC-1 bis AC-4

    /// Verhalten: Der Beispielsatz ist vollstaendig vorhanden (mindestens 51 Dateien).
    func testBeispielsatzMindestanzahl() throws {
        XCTAssertGreaterThanOrEqual(try loadSamples().count, 51)
    }

    /// Verhalten: Jede Lieferung ohne reminder/challenge/tracker wird gelesen (mindestens 32).
    func testAlleLesbarenBeispieleWerdenGelesen() throws {
        let readable = try loadSamples().filter { !isUnsupported($0.delivery) }
        XCTAssertGreaterThanOrEqual(readable.count, 32)
        for s in readable {
            do { _ = try ClaudeDelivery.read(try bytes(s.delivery)) }
            catch { XCTFail("\(s.name) nicht lesbar: \(error)") }
        }
    }

    /// Verhalten: Eine Position reminder/challenge/tracker lehnt die ganze Lieferung ab (mindestens 19).
    func testNichtUnterstuetzteArtenLehnenGanzeLieferungAb() throws {
        let bad = try loadSamples().filter { isUnsupported($0.delivery) }
        XCTAssertGreaterThanOrEqual(bad.count, 19)
        for s in bad {
            let data = try bytes(s.delivery)
            do {
                _ = try ClaudeDelivery.read(data)
                XCTFail("\(s.name) haette abgelehnt werden muessen")
            } catch {
                XCTAssertEqual(error.code, "KIND_NOT_SUPPORTED", s.name)
                XCTAssertFalse(error.reason.isEmpty, s.name)
            }
        }
    }

    /// Verhalten: Uebung, Programm, Atemuebung und Ruecknahme kommen je mindestens einmal als passender Fall an.
    func testJedeArtMindestensEinmalGelesen() throws {
        var seen: Set<String> = []
        for s in try loadSamples() where !isUnsupported(s.delivery) {
            let d = try ClaudeDelivery.read(try bytes(s.delivery))
            for item in d.items {
                switch item {
                case .exercise: seen.insert("exercise")
                case .program: seen.insert("program")
                case .breath: seen.insert("breath")
                case .withdrawal: seen.insert("withdrawal")
                case .unsupported: XCTFail("\(s.name): unsupported in lesbarer Lieferung")
                }
            }
        }
        XCTAssertEqual(seen, ["exercise", "program", "breath", "withdrawal"])
    }

    // MARK: - AC-5

    private func compare(_ item: ClaudeItem, _ raw: Json, _ ctx: String) {
        switch item {
        case .exercise(let e):
            XCTAssertEqual(raw["kind"] as? String, "exercise", ctx)
            XCTAssertEqual(e.itemId, raw["itemId"] as? String, ctx)
            XCTAssertEqual(e.revision, int(raw["revision"]), ctx)
            XCTAssertEqual(e.name, raw["name"] as? String, ctx)
        case .program(let p):
            XCTAssertEqual(raw["kind"] as? String, "program", ctx)
            XCTAssertEqual(p.itemId, raw["itemId"] as? String, ctx)
            XCTAssertEqual(p.revision, int(raw["revision"]), ctx)
            XCTAssertEqual(p.name, raw["name"] as? String, ctx)
            XCTAssertEqual(p.rounds, int(raw["rounds"]), ctx)
            compareSteps(p.steps, raw["steps"] as? [Json] ?? [], ctx)
        case .breath(let b):
            XCTAssertEqual(raw["kind"] as? String, "breath", ctx)
            XCTAssertEqual(b.itemId, raw["itemId"] as? String, ctx)
            XCTAssertEqual(b.revision, int(raw["revision"]), ctx)
            XCTAssertEqual(b.inhaleSeconds, int(raw["inhaleSeconds"]), ctx)
            XCTAssertEqual(b.holdInSeconds, int(raw["holdInSeconds"]), ctx)
            XCTAssertEqual(b.exhaleSeconds, int(raw["exhaleSeconds"]), ctx)
            XCTAssertEqual(b.holdOutSeconds, int(raw["holdOutSeconds"]), ctx)
            XCTAssertEqual(b.rounds, int(raw["rounds"]), ctx)
        case .withdrawal(let w):
            XCTAssertEqual(raw["kind"] as? String, "withdrawal", ctx)
            XCTAssertEqual(w.itemId, raw["itemId"] as? String, ctx)
            XCTAssertEqual(w.packageId, raw["packageId"] as? String, ctx)
        case .unsupported:
            XCTFail("\(ctx): unsupported")
        }
    }

    private func compareSteps(_ steps: [ClaudeProgramStep], _ raw: [Json], _ ctx: String) {
        XCTAssertEqual(steps.count, raw.count, ctx)
        for (step, r) in zip(steps, raw) {
            XCTAssertEqual(step.exerciseId, r["exerciseId"] as? String, ctx)
            XCTAssertEqual(step.workSeconds, int(r["workSeconds"]), ctx)
            XCTAssertEqual(step.restSeconds, int(r["restSeconds"]), ctx)
            XCTAssertEqual(step.hint, r["hint"] as? String, "\(ctx): hint")
        }
    }

    /// Verhalten: Alle gelesenen Felder stimmen mit dem Roh-JSON jeder lesbaren Datei ueberein.
    func testFelderStimmenMitRohJsonUeberein() throws {
        for s in try loadSamples() where !isUnsupported(s.delivery) {
            let d = try ClaudeDelivery.read(try bytes(s.delivery))
            XCTAssertEqual(d.why, s.delivery["why"] as? String, s.name)
            XCTAssertEqual(d.deliveryId, s.delivery["deliveryId"] as? String, s.name)
            let rawPkg = s.delivery["package"] as? Json
            XCTAssertEqual(d.package?.packageId, rawPkg?["packageId"] as? String, s.name)
            XCTAssertEqual(d.package?.name, rawPkg?["name"] as? String, s.name)
            XCTAssertEqual(d.package == nil, rawPkg == nil, s.name)
            let raw = items(s.delivery)
            XCTAssertEqual(d.items.count, raw.count, s.name)
            for (item, r) in zip(d.items, raw) { compare(item, r, s.name) }
        }
    }

    // MARK: - AC-6, AC-7

    /// Verhalten: Das Datum mit Millisekunden stimmt auf die Millisekunde.
    func testCreatedAtMitMillisekundenAufDieMillisekunde() throws {
        let s = try sample("created-at-millis.json")
        let text = try XCTUnwrap(s.delivery["createdAt"] as? String)
        let expected = try XCTUnwrap(iso(text, millis: true))
        let d = try ClaudeDelivery.read(try bytes(s.delivery))
        XCTAssertEqual(d.createdAt.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 0.0005)
    }

    /// Verhalten: Das Datum ohne Millisekunden stimmt.
    func testCreatedAtOhneMillisekunden() throws {
        let s = try sample("package-mixed.json")
        let text = try XCTUnwrap(s.delivery["createdAt"] as? String)
        XCTAssertFalse(text.contains("."), "Beispiel muss ohne Millisekunden sein")
        let expected = try XCTUnwrap(iso(text, millis: false))
        let d = try ClaudeDelivery.read(try bytes(s.delivery))
        XCTAssertEqual(d.createdAt, expected)
    }

    // MARK: - AC-8, AC-9

    private func assertCannotRead(_ data: Data, _ ctx: String) {
        do {
            _ = try ClaudeDelivery.read(data)
            XCTFail("\(ctx): haette APP_CANNOT_READ liefern muessen")
        } catch {
            XCTAssertEqual(error.code, "APP_CANNOT_READ", ctx)
            XCTAssertFalse(error.reason.isEmpty, ctx)
        }
    }

    /// Verhalten: Kein JSON (leer, abgeschnitten, Text) ist "App kann es nicht lesen".
    func testKaputtesJsonIstAppCannotRead() throws {
        let valid = try bytes(try sample("breath.json").delivery)
        assertCannotRead(Data(), "leer")
        assertCannotRead(valid.prefix(valid.count / 2), "abgeschnitten")
        assertCannotRead(Data("das ist kein json".utf8), "Text")
    }

    /// Verhalten: Fehlt ein Pflichtfeld (Huelle, Position, Programm-Runden), kann die App es nicht lesen.
    func testFehlendesPflichtfeldIstAppCannotRead() throws {
        let base = try sample("exercise-and-program.json").delivery
        var noId = base
        noId.removeValue(forKey: "deliveryId")
        assertCannotRead(try bytes(noId), "deliveryId")
        let raw = items(base)
        for (index, item) in raw.enumerated() {
            let kind = item["kind"] as? String ?? ""
            let key = kind == "program" ? "rounds" : "itemId"
            var broken = item
            broken.removeValue(forKey: key)
            var copy = base
            copy["items"] = raw.enumerated().map { $0.offset == index ? broken : $0.element }
            assertCannotRead(try bytes(copy), "\(kind) ohne \(key)")
        }
    }

    // MARK: - AC-10

    /// Verhalten: Unbekannte Zusatzschluessel in Huelle, Position und Schritt aendern nichts.
    func testUnbekannterZusatzschluesselWirdToleriert() throws {
        let base = try sample("exercise-and-program.json").delivery
        let expected = try ClaudeDelivery.read(try bytes(base))
        var extended = base
        extended["unbekannt"] = "x"
        extended["items"] = items(base).map { item -> Json in
            var i = item
            i["unbekannt"] = 42
            if let steps = i["steps"] as? [Json] {
                i["steps"] = steps.map { step -> Json in
                    var s = step
                    s["unbekannt"] = true
                    return s
                }
            }
            return i
        }
        XCTAssertEqual(try ClaudeDelivery.read(try bytes(extended)), expected)
    }

    // MARK: - AC-12

    /// Verhalten: Die Modelldatei importiert nur Foundation (Watch und Widget bleiben unberuehrt).
    func testModellImportiertNurFoundation() throws {
        let url = testDir().appendingPathComponent("../Meditationstimer iOS/Models/ClaudeDelivery.swift").standardized
        let text = try String(contentsOf: url, encoding: .utf8)
        let imports = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("import ") }
        XCTAssertFalse(imports.isEmpty, "mindestens ein import erwartet")
        for line in imports { XCTAssertEqual(line, "import Foundation") }
    }
}
