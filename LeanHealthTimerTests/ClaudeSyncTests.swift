//
//  ClaudeSyncTests.swift
//  LeanHealthTimerTests
//
//  TDD RED #57 Schnitt 4: Abgleich der App mit dem Claude-Dienst (AC-1 bis AC-19).
//  Spec: DOCS/specs/features/feature-57-s4-abgleich.md (Regeln R1 bis R11)
//
//  Festgelegte neue Schnittstelle (der Developer implementiert sie danach):
//    ServiceClient.claimDelivery(token:device:) async throws -> (deliveryId: String, delivery: Data)?   // 204 -> nil
//    ServiceClient.reportResult(token:device:body:) async throws                                       // 204 ok
//    ServiceClient.sendTranscript(token:data:) async throws                                            // 204 ok
//    AccountState.withSession(_:) async throws -> T?        // nil ohne Sitzung; bei 401 dropSession(genau dieses Token)
//    ClaudeSync (@MainActor): Ending { notSignedIn, busy, done, stopped }, maxDeliveriesPerPass, lastSnapshotKey,
//      init(account:client:defaults:device:clock:), lastSnapshotAt, run(), resultBody(deliveryId:result:), isSilent(arguments:environment:)
//
//  Es geht nie Netzwerkverkehr hinaus: alle Tests laufen ueber die eigene Attrappe `SyncWire`.
//  Der Annahme-Kern (`ClaudeStore.apply`) und die Abschrift (`TranscriptBuilder`) laufen echt auf einer
//  isolierten UserDefaults-Suite; nur das Netz ist ersetzt.
//

import XCTest
import Foundation
@testable import Lean_Health_Timer

// MARK: - Attrappen (Namen privat, damit nichts mit anderen Testdateien kollidiert)

/// Zeichnet jede Anfrage auf und beantwortet sie je Pfad (letzte Komponente) der Reihe nach; die letzte Antwort wird
/// wiederholt, ohne Vorgabe antwortet die Attrappe 204.
private actor SyncWire: HTTPTransport {
    enum Reply: Sendable {
        case answer(Int, Data)
        case offline
        case cancel
    }

    private(set) var requests: [URLRequest] = []
    private var scripts: [String: [Reply]]
    private var hooks: [String: @MainActor @Sendable () async -> Void] = [:]
    private let endlessClaims: Bool
    private var endlessCounter = 0

    init(claim: [Reply] = [], result: [Reply] = [], transcript: [Reply] = [], endlessClaims: Bool = false) {
        scripts = ["claim": claim, "result": result, "transcript": transcript]
        self.endlessClaims = endlessClaims
    }

    /// Fuehrt `hook` einmal aus, bevor die erste Anfrage dieses Pfads beantwortet wird.
    func onFirst(_ path: String, _ hook: @escaping @MainActor @Sendable () async -> Void) { hooks[path] = hook }

    var paths: [String] { requests.map { $0.url?.lastPathComponent ?? "?" } }

    func bodies(_ path: String) -> [Data] {
        requests.filter { $0.url?.lastPathComponent == path }.map { $0.httpBody ?? Data() }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let path = request.url?.lastPathComponent ?? "?"
        if let hook = hooks.removeValue(forKey: path) { await hook() }
        let reply: Reply
        if endlessClaims && path == "claim" {
            endlessCounter += 1
            reply = claimAnswer(uid(1000 + endlessCounter), items: [noEffectItem()])
        } else {
            reply = next(path)
        }
        switch reply {
        case .offline: throw URLError(.notConnectedToInternet)
        case .cancel: throw CancellationError()
        case .answer(let status, let data):
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
            return (data, response)
        }
    }

    private func next(_ path: String) -> Reply {
        var queue = scripts[path] ?? []
        guard !queue.isEmpty else { return .answer(204, Data()) }
        let reply = queue.count > 1 ? queue.removeFirst() : queue[0]
        scripts[path] = queue
        return reply
    }
}

private typealias Json = [String: Any]

/// Deliveries haben UUID-Form (wie beim Dienst).
private func uid(_ n: Int) -> String { String(format: "00000000-0000-4000-8000-%012d", n) }

private func noEffectItem() -> Json { ["kind": "withdrawal", "itemId": "claude.gibt-es-nicht"] }

private func programItem(_ id: String = "claude.prog", rev: Int = 1, name: String = "Programm P") -> Json {
    ["kind": "program", "itemId": id, "revision": rev, "name": name, "symbol": "💪", "rounds": 2,
     "steps": [["exerciseId": "builtin.planke", "workSeconds": 30, "restSeconds": 10] as Json]]
}

/// Ein Programm mit einer Uebung, die die App nicht kennt: der Annahme-Kern lehnt es ab (EXERCISE_UNKNOWN).
private func unknownStepProgram(_ id: String = "claude.kaputt") -> Json {
    ["kind": "program", "itemId": id, "revision": 1, "name": "Kaputt", "symbol": "💪", "rounds": 1,
     "steps": [["exerciseId": "builtin.gibt-es-nicht", "workSeconds": 30, "restSeconds": 10] as Json]]
}

private func deliveryObject(_ id: String, items: [Json]) -> Json {
    ["format": "hhhaven.delivery/1", "deliveryId": id, "source": "claude",
     "createdAt": "2026-11-13T10:15:00Z", "why": "Weil es passt.", "items": items]
}

/// Antwort des Dienstes auf `claim`: Umschlag `{deliveryId, delivery}` mit roher Lieferung.
private func envelope(_ id: String, delivery: Json) -> SyncWire.Reply {
    .answer(200, (try? JSONSerialization.data(withJSONObject: ["deliveryId": id, "delivery": delivery] as Json)) ?? Data())
}

private func claimAnswer(_ id: String, items: [Json]) -> SyncWire.Reply {
    envelope(id, delivery: deliveryObject(id, items: items))
}

private func parse(_ data: Data) -> Json {
    ((try? JSONSerialization.jsonObject(with: data)) as? Json) ?? [:]
}

private func readError(_ data: Data) -> ClaudeDeliveryError? {
    do { _ = try ClaudeDelivery.read(data); return nil } catch { return error as? ClaudeDeliveryError }
}

private final class StepClock {
    let base = ClaudeSyncTestsDates.firstNow
    private var calls = 0
    func next() -> Date { defer { calls += 1 }; return base.addingTimeInterval(Double(calls) * 60) }
}

private enum ClaudeSyncTestsDates {
    static let firstNow: Date = parseUTC("2026-11-24T10:00:00Z")
    static func parseUTC(_ s: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)!
    }
}

private final class DeviceProbe {
    let id = UUID(uuidString: "AAAAAAAA-0000-4000-8000-00000000D00D")!
    var calls = 0
    var failing = false
    func read() throws -> UUID {
        calls += 1
        if failing { throw DeviceIdentityError.corruptData }
        return id
    }
}

// MARK: - Tests

@MainActor
final class ClaudeSyncTests: XCTestCase {

    private static let base = URL(string: "https://example.test")!
    private let setsKey = "workoutProgramSets"
    private let presetsKey = "atemPresets"
    private let stateKey = "claudeState"

    @MainActor
    private final class Rig {
        let defaults: UserDefaults
        let store: InMemorySessionStore
        let wire: SyncWire
        let account: AccountState
        let clock = StepClock()
        let device = DeviceProbe()
        let sync: ClaudeSync

        init(defaults: UserDefaults, wire: SyncWire, token: String?) {
            self.defaults = defaults
            self.wire = wire
            store = InMemorySessionStore(token: token)
            let client = ServiceClient(baseURL: ClaudeSyncTests.base, transport: wire)
            account = AccountState(client: client, store: store)
            let clock = self.clock, device = self.device
            sync = ClaudeSync(account: account, client: client, defaults: defaults,
                              device: { try device.read() }, clock: { clock.next() })
        }
    }

    private func makeRig(_ wire: SyncWire = SyncWire(), token: String? = "T1") -> Rig {
        let name = "ClaudeSyncTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        addTeardownBlock { UserDefaults(suiteName: name)?.removePersistentDomain(forName: name) }
        return Rig(defaults: defaults, wire: wire, token: token)
    }

    private func state(_ defaults: UserDefaults) -> ClaudeStoredState { ClaudeStore.readState(from: defaults).state }

    private func iso(_ text: String) -> Date { ClaudeSyncTestsDates.parseUTC(text) }

    // MARK: AC-1

    /// Verhalten: Zwei wartende Lieferungen werden abgeholt, angewendet, gemeldet; erst danach geht die Abschrift raus
    /// und enthaelt die Ergebnisse beider Lieferungen.
    func testAblaufReihenfolgeClaimResultClaimTranscript() async throws {
        let wire = SyncWire(claim: [claimAnswer(uid(1), items: [programItem("claude.eins")]),
                                    claimAnswer(uid(2), items: [programItem("claude.zwei")]),
                                    .answer(204, Data())])
        let rig = makeRig(wire)
        let ending = await rig.sync.run()
        XCTAssertEqual(ending, .done)
        let paths = await wire.paths
        XCTAssertEqual(paths, ["claim", "result", "claim", "result", "claim", "transcript"])
        let results = await wire.bodies("result").map(parse)
        XCTAssertEqual(results.compactMap { $0["deliveryId"] as? String }, [uid(1), uid(2)],
                       "jedes result traegt die deliveryId der vorangehenden claim-Antwort")
        XCTAssertEqual(state(rig.defaults).log.map(\.deliveryId), [uid(1), uid(2)], "beide Lieferungen sind im Log verzeichnet")
        let raw1 = await wire.bodies("transcript").first
        let transcript = parse(try XCTUnwrap(raw1))
        let deliveries = try XCTUnwrap(transcript["deliveries"] as? [Json])
        XCTAssertEqual(deliveries.compactMap { $0["deliveryId"] as? String }, [uid(1), uid(2)],
                       "die Abschrift spiegelt das gerade Angewendete")
        XCTAssertEqual(deliveries.compactMap { $0["outcome"] as? String }, ["accepted", "accepted"])
    }

    // MARK: AC-2

    /// Verhalten: Liefert der Dienst unbegrenzt, werden genau 15 Lieferungen bearbeitet, kein 16. claim, danach eine Abschrift.
    func testHoechstens15LieferungenDanachAbschrift() async {
        XCTAssertEqual(ClaudeSync.maxDeliveriesPerPass, 15)
        let wire = SyncWire(endlessClaims: true)
        let rig = makeRig(wire)
        let ending = await rig.sync.run()
        XCTAssertEqual(ending, .done)
        let paths = await wire.paths
        XCTAssertEqual(paths.filter { $0 == "claim" }.count, 15)
        XCTAssertEqual(paths.filter { $0 == "result" }.count, 15)
        XCTAssertEqual(paths.filter { $0 == "transcript" }.count, 1)
        XCTAssertEqual(paths.last, "transcript")
        XCTAssertEqual(paths.count, 31)
        let ids = await wire.bodies("result").compactMap { parse($0)["deliveryId"] as? String }
        XCTAssertEqual(Set(ids).count, 15, "15 verschiedene Lieferungen gemeldet")
    }

    // MARK: AC-3

    /// Verhalten: Ist nichts offen (204), gibt es kein result, aber die Abschrift geht trotzdem raus und entspricht dem Bestand.
    func testNichtsOffenBeendetSchleifeUndSendetAbschrift() async throws {
        let wire = SyncWire(claim: [.answer(204, Data())])
        let rig = makeRig(wire)
        let ending = await rig.sync.run()
        XCTAssertEqual(ending, .done)
        let paths = await wire.paths
        XCTAssertEqual(paths, ["claim", "transcript"])
        let input = TranscriptBuilder.readCurrent(defaults: rig.defaults)
        let expected = TranscriptBuilder.build(sets: input.sets, presets: input.presets,
                                               claudeExercises: input.claudeExercises, log: input.log,
                                               now: rig.clock.base)
        let raw2 = await wire.bodies("transcript").first
        let sent = try XCTUnwrap(raw2)
        XCTAssertEqual(sent, expected, "gesendet wird genau, was TranscriptBuilder fuer diesen Bestand und dieses now baut")
    }

    /// Verhalten (R8): Nur 204 heisst "nichts offen". Eine 200 mit leerem Koerper ist eine ungueltige Antwort:
    /// kein Abschrift-Versand, lastSnapshotAt unveraendert, Durchlauf endet `.stopped`.
    func testLeere200BeimAbholenIstUngueltigeAntwort() async throws {
        let client = ServiceClient(baseURL: ClaudeSyncTests.base, transport: SyncWire(claim: [.answer(200, Data())]))
        do {
            _ = try await client.claimDelivery(token: "T1", device: UUID())
            XCTFail("leere 200 muss .invalidResponse werfen")
        } catch {
            XCTAssertEqual(error as? ServiceError, .invalidResponse)
        }

        let wire = SyncWire(claim: [.answer(200, Data())])
        let rig = makeRig(wire)
        let ending = await rig.sync.run()
        XCTAssertEqual(ending, .stopped)
        let paths = await wire.paths
        XCTAssertEqual(paths, ["claim"], "keine Abschrift nach kaputter Antwort")
        XCTAssertNil(rig.sync.lastSnapshotAt)
    }

    // MARK: AC-4

    /// Verhalten: 409 beim Melden (Dienst kennt die Lieferung nicht mehr) wird verworfen; die zweite Lieferung folgt.
    func testKonflikt409BeimMeldenWirdVerworfen() async {
        let wire = SyncWire(claim: [claimAnswer(uid(1), items: [programItem("claude.eins")]),
                                    claimAnswer(uid(2), items: [programItem("claude.zwei")]),
                                    .answer(204, Data())],
                            result: [.answer(409, Data()), .answer(204, Data())])
        let rig = makeRig(wire)
        let ending = await rig.sync.run()
        XCTAssertEqual(ending, .done)
        let paths = await wire.paths
        XCTAssertEqual(paths, ["claim", "result", "claim", "result", "claim", "transcript"])
        let ids = await wire.bodies("result").compactMap { parse($0)["deliveryId"] as? String }
        XCTAssertEqual(ids, [uid(1), uid(2)], "die erste Lieferung wird nicht erneut gemeldet")
    }

    // MARK: AC-5

    /// Verhalten: 401 bei claim, result oder transcript meldet ab (Token weg, abgemeldet), danach keine Anfrage mehr.
    func testUnauthorizedMeldetAbUeberWithSession() async {
        let cases: [(String, SyncWire, [String])] = [
            ("claim", SyncWire(claim: [.answer(401, Data())]), ["claim"]),
            ("result", SyncWire(claim: [claimAnswer(uid(1), items: [programItem()])],
                                result: [.answer(401, Data())]), ["claim", "result"]),
            ("transcript", SyncWire(claim: [.answer(204, Data())],
                                    transcript: [.answer(401, Data())]), ["claim", "transcript"]),
        ]
        for (label, wire, expectedPaths) in cases {
            let rig = makeRig(wire)
            let ending = await rig.sync.run()
            XCTAssertEqual(ending, .stopped, "401 bei \(label)")
            let paths = await wire.paths
            XCTAssertEqual(paths, expectedPaths, "keine weitere Anfrage nach der 401 bei \(label)")
            XCTAssertNil(rig.store.token, "Sitzung geraeumt bei \(label)")
            XCTAssertEqual(rig.account.status, .signedOut, "abgemeldet bei \(label)")
            XCTAssertNil(rig.sync.lastSnapshotAt, "keine Abschrift, kein lastSnapshotAt bei \(label)")
        }
    }

    /// Verhalten: Eine veraltete 401 loescht keine inzwischen angelegte neuere Sitzung.
    func testVeraltete401LoeschtKeineNeuereSitzung() async {
        let wire = SyncWire(claim: [.answer(401, Data())])
        let rig = makeRig(wire)
        let store = rig.store
        await wire.onFirst("claim") { try? store.save("T2") }
        let ending = await rig.sync.run()
        XCTAssertEqual(ending, .stopped)
        XCTAssertEqual(rig.store.token, "T2", "die neuere Sitzung bleibt erhalten")
        let paths = await wire.paths
        XCTAssertEqual(paths, ["claim"])
    }

    // MARK: AC-6

    /// Verhalten: Jeder andere Fehler beendet den Durchlauf still: keine Wiederholung, keine Abschrift
    /// (ausser beim Fehler der Abschrift selbst), Sitzung und lastSnapshotAt unveraendert.
    func testSonstigerFehlerBeendetStillOhneAbschrift() async {
        let one = claimAnswer(uid(1), items: [programItem()])
        let garbage = SyncWire.Reply.answer(200, Data("kein json".utf8))
        let cases: [(String, SyncWire, [String])] = [
            ("claim 500", SyncWire(claim: [.answer(500, Data())]), ["claim"]),
            ("claim 429", SyncWire(claim: [.answer(429, Data())]), ["claim"]),
            ("claim offline", SyncWire(claim: [.offline]), ["claim"]),
            ("claim abgebrochen", SyncWire(claim: [.cancel]), ["claim"]),
            ("claim ungueltige Antwort", SyncWire(claim: [garbage]), ["claim"]),
            ("result 500", SyncWire(claim: [one], result: [.answer(500, Data())]), ["claim", "result"]),
            ("result offline", SyncWire(claim: [one], result: [.offline]), ["claim", "result"]),
            ("result 400", SyncWire(claim: [one], result: [.answer(400, Data())]), ["claim", "result"]),
            ("transcript 400", SyncWire(claim: [.answer(204, Data())], transcript: [.answer(400, Data())]), ["claim", "transcript"]),
            ("transcript offline", SyncWire(claim: [.answer(204, Data())], transcript: [.offline]), ["claim", "transcript"]),
            ("transcript 413", SyncWire(claim: [.answer(204, Data())], transcript: [.answer(413, Data())]), ["claim", "transcript"]),
        ]
        for (label, wire, expectedPaths) in cases {
            let rig = makeRig(wire)
            let ending = await rig.sync.run()
            XCTAssertEqual(ending, .stopped, label)
            let paths = await wire.paths
            XCTAssertEqual(paths, expectedPaths, "genau die Anfragen bis zum Fehler, ohne Wiederholung: \(label)")
            XCTAssertEqual(rig.store.token, "T1", "Sitzung unveraendert: \(label)")
            XCTAssertEqual(rig.account.status, .signedIn, label)
            XCTAssertNil(rig.sync.lastSnapshotAt, "lastSnapshotAt unveraendert: \(label)")
        }
    }

    // MARK: AC-7

    /// Verhalten: `applied` und `noEffect` werden beide als genau `{deliveryId, outcome: "accepted"}` gemeldet.
    func testErgebnisKoerperAcceptedFuerAppliedUndNoEffect() async {
        let wire = SyncWire(claim: [claimAnswer(uid(1), items: [programItem("claude.neu")]),   // applied
                                    claimAnswer(uid(2), items: [noEffectItem()]),              // noEffect
                                    .answer(204, Data())])
        let rig = makeRig(wire)
        _ = await rig.sync.run()
        let log = state(rig.defaults).log
        XCTAssertEqual(log.map(\.result), [.applied, .noEffect], "Ausgangslage: applied und noEffect")
        let bodies = await wire.bodies("result").map(parse)
        XCTAssertEqual(bodies.count, 2)
        for (body, id) in zip(bodies, [uid(1), uid(2)]) {
            XCTAssertEqual(Set(body.keys), ["deliveryId", "outcome"])
            XCTAssertEqual(body["deliveryId"] as? String, id)
            XCTAssertEqual(body["outcome"] as? String, "accepted")
        }
    }

    // MARK: AC-8

    /// Verhalten: Eine abgelehnte oder unlesbare Lieferung wird als `rejected` mit genau einem Fehler gemeldet
    /// (code, path "", message); die deliveryId kommt aus dem Umschlag.
    func testErgebnisKoerperRejectedMitFehlerliste() async throws {
        let unreadable: Json = ["format": "hhhaven.delivery/1", "deliveryId": uid(2), "items": "kaputt"]
        let unreadableData = try JSONSerialization.data(withJSONObject: unreadable)
        let expectedError = try XCTUnwrap(readError(unreadableData), "Ausgangslage: Lieferung ist wirklich unlesbar")
        let wire = SyncWire(claim: [claimAnswer(uid(1), items: [unknownStepProgram()]),
                                    envelope(uid(2), delivery: unreadable),
                                    .answer(204, Data())])
        let rig = makeRig(wire)
        let ending = await rig.sync.run()
        XCTAssertEqual(ending, .done)
        guard case .rejected(let code, let reason) = try XCTUnwrap(state(rig.defaults).log.first).result else {
            return XCTFail("Ausgangslage: Annahme-Kern lehnt die erste Lieferung ab")
        }
        let bodies = await wire.bodies("result").map(parse)
        XCTAssertEqual(bodies.count, 2)
        let expected: [(String, String, String)] = [(uid(1), code, reason), (uid(2), expectedError.code, expectedError.reason)]
        for (body, (id, wantCode, wantMessage)) in zip(bodies, expected) {
            XCTAssertEqual(Set(body.keys), ["deliveryId", "outcome", "errors"])
            XCTAssertEqual(body["deliveryId"] as? String, id)
            XCTAssertEqual(body["outcome"] as? String, "rejected")
            let errors = try XCTUnwrap(body["errors"] as? [Json])
            XCTAssertEqual(errors.count, 1)
            let error = try XCTUnwrap(errors.first)
            XCTAssertEqual(Set(error.keys), ["code", "path", "message"])
            XCTAssertEqual(error["code"] as? String, wantCode)
            XCTAssertEqual(error["path"] as? String, "")
            XCTAssertEqual(error["message"] as? String, wantMessage)
        }
    }

    // MARK: AC-9

    /// Verhalten: `code` (1 bis 100) und `message` (1 bis 300) werden in UTF-16-Einheiten wie JavaScript `length`
    /// gekuerzt, nur an Zeichengrenzen; leer ergibt den Ersatzwert; der Koerper bleibt klein.
    func testErgebnisKoerperGrenzenKlemmenKuerzenErsatzwert() throws {
        func error(code: String, message: String) throws -> Json {
            let data = ClaudeSync.resultBody(deliveryId: uid(1), result: .rejected(code: code, reason: message))
            let body = parse(data)
            XCTAssertEqual(Set(body.keys), ["deliveryId", "outcome", "errors"])
            XCTAssertEqual(body["outcome"] as? String, "rejected")
            return try XCTUnwrap((body["errors"] as? [Json])?.first)
        }
        func length(_ e: Json, _ key: String) -> Int { (e[key] as? String)?.utf16.count ?? -1 }

        let hundred = String(repeating: "c", count: 100)
        XCTAssertEqual(length(try error(code: hundred, message: "m"), "code"), 100)
        XCTAssertEqual(length(try error(code: hundred + "c", message: "m"), "code"), 100)
        XCTAssertEqual(try error(code: "", message: "m")["code"] as? String, "unknown")

        let threeHundred = String(repeating: "m", count: 300)
        XCTAssertEqual(length(try error(code: "c", message: threeHundred), "message"), 300)
        XCTAssertEqual(length(try error(code: "c", message: threeHundred + "m"), "message"), 300)
        XCTAssertEqual(try error(code: "c", message: "")["message"] as? String, "no reason given")

        // Emoji ausserhalb der Grundebene = 2 UTF-16-Einheiten: 299 + 2 = 301, also faellt es ganz weg.
        let emoji = String(repeating: "m", count: 299) + "😀"
        let cutEmoji = try XCTUnwrap(try error(code: "c", message: emoji)["message"] as? String)
        XCTAssertLessThanOrEqual(cutEmoji.utf16.count, 300)
        XCTAssertEqual(cutEmoji, String(repeating: "m", count: 299), "kein halbes Surrogatpaar")
        let cutCode = try XCTUnwrap(try error(code: String(repeating: "c", count: 99) + "😀", message: "m")["code"] as? String)
        XCTAssertEqual(cutCode, String(repeating: "c", count: 99))

        // Zusammengesetztes Emoji (Familie, 11 Einheiten) wird nicht zerteilt.
        let family = String(repeating: "m", count: 295) + "👨‍👩‍👧‍👦"
        let cutFamily = try XCTUnwrap(try error(code: "c", message: family)["message"] as? String)
        XCTAssertLessThanOrEqual(cutFamily.utf16.count, 300)
        XCTAssertEqual(cutFamily, String(repeating: "m", count: 295), "kein zerteiltes Emoji")

        // Sehr lange Meldung: der Koerper bleibt unter 256 KB und ist gueltiges UTF-8-JSON.
        let huge = ClaudeSync.resultBody(deliveryId: uid(1), result: .rejected(code: String(repeating: "c", count: 500_000),
                                                                             reason: String(repeating: "ä", count: 500_000)))
        XCTAssertLessThan(huge.count, 256 * 1024)
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: huge))
        XCTAssertNotNil(String(data: huge, encoding: .utf8))

        // accepted traegt keine weiteren Schluessel.
        for result in [ClaudeApplyResult.applied, .noEffect] {
            let body = parse(ClaudeSync.resultBody(deliveryId: uid(3), result: result))
            XCTAssertEqual(Set(body.keys), ["deliveryId", "outcome"])
            XCTAssertEqual(body["outcome"] as? String, "accepted")
            XCTAssertEqual(body["deliveryId"] as? String, uid(3))
        }
    }

    // MARK: AC-10

    /// Verhalten: Die Geraete-Kennung wird je Durchlauf einmal gelesen und steht in allen claim- und result-Anfragen;
    /// ein Lesefehler beendet den Durchlauf ohne Anfrage.
    func testGeraeteKennungEinmalJeDurchlauf() async throws {
        let wire = SyncWire(claim: [claimAnswer(uid(1), items: [programItem("claude.eins")]),
                                    claimAnswer(uid(2), items: [programItem("claude.zwei")]),
                                    .answer(204, Data())])
        let rig = makeRig(wire)
        _ = await rig.sync.run()
        XCTAssertEqual(rig.device.calls, 1)
        let requests = await wire.requests
        let routed = requests.filter { ["claim", "result"].contains($0.url?.lastPathComponent ?? "") }
        XCTAssertEqual(routed.count, 5)
        for request in routed {
            let header = try XCTUnwrap(request.value(forHTTPHeaderField: "X-Device"))
            XCTAssertEqual(UUID(uuidString: header), rig.device.id)
        }
        _ = await rig.sync.run()
        XCTAssertEqual(rig.device.calls, 2, "ein zweiter Durchlauf liest erneut")

        let failing = SyncWire()
        let broken = makeRig(failing)
        broken.device.failing = true
        let ending = await broken.sync.run()
        XCTAssertEqual(ending, .stopped)
        let paths = await failing.paths
        XCTAssertTrue(paths.isEmpty, "ohne Geraete-Kennung keine Anfrage")
    }

    // MARK: AC-11

    /// Verhalten: Nach 204 der Abschrift steht lastSnapshotAt (eigener Schluessel, nicht claudeState) auf genau dem
    /// `now`, das in generatedAt der gesendeten Abschrift steht und vor dem Lesen des Bestands erfasst wurde.
    func testLastSnapshotAtErstNachAbschrift204Gesetzt() async throws {
        let wire = SyncWire(claim: [.answer(204, Data())])
        let rig = makeRig(wire)
        XCTAssertNil(rig.sync.lastSnapshotAt, "erster Lauf: nil")
        XCTAssertNotEqual(ClaudeSync.lastSnapshotKey, stateKey)
        let ending = await rig.sync.run()
        XCTAssertEqual(ending, .done)
        let raw3 = await wire.bodies("transcript").first
        let sent = parse(try XCTUnwrap(raw3))
        let generatedAt = iso(try XCTUnwrap(sent["generatedAt"] as? String))
        XCTAssertEqual(rig.sync.lastSnapshotAt, generatedAt, "gleich dem now der gesendeten Abschrift")
        XCTAssertEqual(rig.sync.lastSnapshotAt, rig.clock.base, "es gilt der erste Wert der Uhr")
        XCTAssertNotNil(rig.defaults.object(forKey: ClaudeSync.lastSnapshotKey), "eigener Schluessel in den Defaults")
        XCTAssertNil(rig.defaults.object(forKey: stateKey), "nicht in claudeState abgelegt")
    }

    /// Verhalten: Scheitert die Abschrift (400, 500, offline), bleibt lastSnapshotAt wie es war (leer beim ersten Lauf,
    /// alter Wert bei einem spaeteren).
    func testLastSnapshotAtBeiFehlerUnveraendert() async {
        for failure in [SyncWire.Reply.answer(400, Data()), .answer(500, Data()), .offline] {
            let first = makeRig(SyncWire(claim: [.answer(204, Data())], transcript: [failure]))
            let ending = await first.sync.run()
            XCTAssertEqual(ending, .stopped)
            XCTAssertNil(first.sync.lastSnapshotAt, "erster Lauf bleibt leer")
            XCTAssertNil(first.defaults.object(forKey: ClaudeSync.lastSnapshotKey))

            let wire = SyncWire(claim: [.answer(204, Data())], transcript: [.answer(204, Data()), failure])
            let later = makeRig(wire)
            _ = await later.sync.run()
            let old = later.sync.lastSnapshotAt
            XCTAssertNotNil(old)
            let again = await later.sync.run()
            XCTAssertEqual(again, .stopped)
            XCTAssertEqual(later.sync.lastSnapshotAt, old, "alter Wert bleibt bei Fehler der naechsten Abschrift")
        }
    }

    // MARK: AC-12

    /// Verhalten: lastSnapshotAt geht an den Annahme-Kern. Hat Henning ein Programm geaendert, wird die Aenderung im
    /// ersten Lauf (kein lastSnapshotAt) abgelehnt und im naechsten Lauf (Abschrift danach) angenommen.
    func testLastSnapshotAtWirdAnApplyUebergeben() async throws {
        let wire = SyncWire(claim: [claimAnswer(uid(1), items: [programItem("claude.prog", rev: 2, name: "Neu Eins")]),
                                    .answer(204, Data()),
                                    claimAnswer(uid(2), items: [programItem("claude.prog", rev: 2, name: "Neu Zwei")]),
                                    .answer(204, Data())])
        let rig = makeRig(wire)
        let origin = ClaudeOrigin(itemId: "claude.prog", revision: 1, why: "alt", packageId: nil, packageName: nil,
                                  deliveredAt: iso("2026-11-10T08:00:00Z"))
        let seeded = WorkoutSet(id: UUID(uuidString: "BBBBBBBB-0000-4000-8000-000000000001")!, name: "Claude Programm",
                                emoji: "💪",
                                phases: [WorkoutPhase(name: "Planke", workDuration: 30, restDuration: 10, exerciseId: "builtin.planke")],
                                repetitions: 2, claude: origin, modifiedAt: iso("2026-11-20T09:00:00Z"))
        rig.defaults.set(try JSONEncoder().encode([seeded]), forKey: setsKey)
        func storedNames() throws -> [String] {
            let data = try XCTUnwrap(rig.defaults.data(forKey: setsKey))
            return try JSONDecoder().decode([WorkoutSet].self, from: data).filter { $0.claude != nil }.map(\.name)
        }

        XCTAssertNil(rig.sync.lastSnapshotAt)
        let first = await rig.sync.run()
        XCTAssertEqual(first, .done)
        let raw4 = await wire.bodies("result").first
        let firstBody = parse(try XCTUnwrap(raw4))
        XCTAssertEqual(firstBody["outcome"] as? String, "rejected", "ohne lastSnapshotAt gilt die Aenderung von Henning als blockiert")
        XCTAssertEqual((firstBody["errors"] as? [Json])?.first?["code"] as? String, "CHANGED_ON_IPHONE")
        XCTAssertEqual(try storedNames(), ["Claude Programm"])
        XCTAssertNotNil(rig.sync.lastSnapshotAt, "Abschrift 204 setzt lastSnapshotAt")

        let second = await rig.sync.run()
        XCTAssertEqual(second, .done)
        let raw5 = await wire.bodies("result").last
        let secondBody = parse(try XCTUnwrap(raw5))
        XCTAssertEqual(secondBody["outcome"] as? String, "accepted", "lastSnapshotAt liegt nach modifiedAt: Aenderung wird angenommen")
        XCTAssertEqual(try storedNames(), ["Neu Zwei"])
    }

    // MARK: AC-13

    /// Verhalten: Ist der gespeicherte Bestand nicht lesbar, geht keine Abschrift raus (Claude sahe sonst eine leere Welt);
    /// der Durchlauf endet trotzdem `done`, lastSnapshotAt bleibt.
    func testUnlesbarerBestandSendetKeineAbschrift() async {
        for key in [stateKey, setsKey, presetsKey] {
            let wire = SyncWire(claim: [.answer(204, Data())])
            let rig = makeRig(wire)
            rig.defaults.set(Data("das ist kein json".utf8), forKey: key)
            let ending = await rig.sync.run()
            XCTAssertEqual(ending, .done, "unlesbar: \(key)")
            let paths = await wire.paths
            XCTAssertEqual(paths, ["claim"], "keine Abschrift bei unlesbarem \(key)")
            XCTAssertNil(rig.sync.lastSnapshotAt, "lastSnapshotAt bleibt bei unlesbarem \(key)")
        }
    }

    // MARK: AC-14

    /// Verhalten: Ohne Sitzung (leer oder Lesefehler im Speicher) endet der Abgleich ohne jeden Netzverkehr.
    func testOhneSitzungKeinNetzverkehr() async {
        let emptyWire = SyncWire()
        let empty = makeRig(emptyWire, token: nil)
        let endingEmpty = await empty.sync.run()
        XCTAssertEqual(endingEmpty, .notSignedIn)
        let emptyPaths = await emptyWire.paths
        XCTAssertTrue(emptyPaths.isEmpty)
        XCTAssertNil(empty.sync.lastSnapshotAt)

        let wire = SyncWire(claim: [.answer(204, Data())])
        let rig = makeRig(wire)
        _ = await rig.sync.run()
        let before = rig.sync.lastSnapshotAt
        XCTAssertNotNil(before)
        let pathsBefore = await wire.paths
        let requestsBefore = pathsBefore.count
        rig.store.failNext(load: true)
        let ending = await rig.sync.run()
        XCTAssertEqual(ending, .notSignedIn, "Lesefehler im Sitzungsspeicher zaehlt als keine Sitzung")
        let pathsNow = await wire.paths
        let requestsAfter = pathsNow.count
        XCTAssertEqual(requestsAfter, requestsBefore, "kein Netzverkehr")
        XCTAssertEqual(rig.sync.lastSnapshotAt, before, "lastSnapshotAt unveraendert")
    }

    // MARK: AC-15

    /// Verhalten: Ein zweiter run() waehrend eines laufenden Durchlaufs liefert `busy` und sendet nichts;
    /// danach ist ein neuer Durchlauf wieder moeglich.
    func testDoppellaufLiefertBusy() async {
        let wire = SyncWire(claim: [.answer(204, Data())])
        let rig = makeRig(wire)
        let sync = rig.sync
        let inner = EndingBox()
        await wire.onFirst("claim") { inner.value = await sync.run() }
        let ending = await rig.sync.run()
        XCTAssertEqual(inner.value, .busy)
        XCTAssertEqual(ending, .done)
        let paths = await wire.paths
        XCTAssertEqual(paths, ["claim", "transcript"], "der zweite Lauf hat nichts gesendet")
        let again = await rig.sync.run()
        XCTAssertEqual(again, .done, "danach ist ein neuer Durchlauf wieder moeglich")
        let pathsAfter = await wire.paths
        XCTAssertEqual(pathsAfter, ["claim", "transcript", "claim", "transcript"])
    }

    private final class EndingBox: @unchecked Sendable { var value: ClaudeSync.Ending? }

    // MARK: AC-16

    /// Verhalten: Scheitert das Melden und der Dienst liefert dieselbe Lieferung erneut, aendert der zweite Durchlauf den
    /// Bestand nicht ein zweites Mal, meldet dasselbe Ergebnis und schliesst mit Abschrift ab.
    func testZweiterDurchlaufMitGleicherLieferungIstIdempotent() async throws {
        let delivery = claimAnswer(uid(1), items: [programItem("claude.einmal")])
        let wire = SyncWire(claim: [delivery, delivery, .answer(204, Data())],
                            result: [.answer(500, Data()), .answer(204, Data())])
        let rig = makeRig(wire)
        let first = await rig.sync.run()
        XCTAssertEqual(first, .stopped)
        let setsAfterFirst = try XCTUnwrap(rig.defaults.data(forKey: setsKey))
        let stateAfterFirst = try XCTUnwrap(rig.defaults.data(forKey: stateKey))
        XCTAssertEqual(state(rig.defaults).log.map(\.deliveryId), [uid(1)])
        let pathsFirst = await wire.paths
        XCTAssertFalse(pathsFirst.contains("transcript"), "keine Abschrift nach Fehler")

        let second = await rig.sync.run()
        XCTAssertEqual(second, .done)
        XCTAssertEqual(rig.defaults.data(forKey: setsKey), setsAfterFirst, "Bausteine nicht ein zweites Mal veraendert")
        XCTAssertEqual(rig.defaults.data(forKey: stateKey), stateAfterFirst, "Log unveraendert, kein doppelter Eintrag")
        XCTAssertEqual(state(rig.defaults).log.filter { $0.deliveryId == uid(1) }.count, 1)
        let bodies = await wire.bodies("result").map(parse)
        XCTAssertEqual(bodies.count, 2)
        XCTAssertEqual(bodies[0]["outcome"] as? String, "accepted")
        XCTAssertEqual(bodies[0] as NSDictionary, bodies[1] as NSDictionary, "gleiches Ergebnis, gleicher Koerper")
        let all = await wire.paths
        XCTAssertEqual(all.last, "transcript", "der zweite Durchlauf schliesst mit Abschrift")
    }

    // MARK: AC-17

    /// Verhalten: withSession gibt der Aktion das Token, laeuft ohne Sitzung nicht, meldet bei 401 ab (ohne eine neuere
    /// Sitzung zu loeschen) und laesst die Sitzung bei jedem anderen Fehler unveraendert.
    func testWithSessionTokenOhneSitzungUnd401() async throws {
        func account(token: String?) -> (AccountState, InMemorySessionStore) {
            let store = InMemorySessionStore(token: token)
            let client = ServiceClient(baseURL: Self.base, transport: SyncWire())
            return (AccountState(client: client, store: store), store)
        }

        let (signedIn, _) = account(token: "T1")
        var seen: String?
        let value: Int? = try await signedIn.withSession { token in seen = token; return 7 }
        XCTAssertEqual(value, 7)
        XCTAssertEqual(seen, "T1", "die Aktion bekommt das gespeicherte Token")

        let (signedOut, _) = account(token: nil)
        var ran = false
        let none: Int? = try await signedOut.withSession { _ in ran = true; return 1 }
        XCTAssertNil(none)
        XCTAssertFalse(ran, "ohne Sitzung laeuft die Aktion nicht")

        let (unreadable, unreadableStore) = account(token: "T1")
        unreadableStore.failNext(load: true)
        let unread: Int? = try await unreadable.withSession { _ in ran = true; return 1 }
        XCTAssertNil(unread)
        XCTAssertFalse(ran, "bei Lesefehler laeuft die Aktion nicht")

        let (rejected, rejectedStore) = account(token: "T1")
        do {
            let _: Int? = try await rejected.withSession { _ in throw ServiceError.unauthorized }
            XCTFail("der Fehler muss weitergereicht werden")
        } catch {
            XCTAssertEqual(error as? ServiceError, .unauthorized)
        }
        XCTAssertNil(rejectedStore.token, "401 loescht die Sitzung")
        XCTAssertEqual(rejected.status, .signedOut)

        let (stale, staleStore) = account(token: "T1")
        do {
            let _: Int? = try await stale.withSession { _ in
                try staleStore.save("T2")
                throw ServiceError.unauthorized
            }
            XCTFail("der Fehler muss weitergereicht werden")
        } catch {
            XCTAssertEqual(error as? ServiceError, .unauthorized)
        }
        XCTAssertEqual(staleStore.token, "T2", "veraltete 401 loescht keine neuere Sitzung")

        let (other, otherStore) = account(token: "T1")
        do {
            let _: Int? = try await other.withSession { _ in throw ServiceError.rejected(500) }
            XCTFail("der Fehler muss weitergereicht werden")
        } catch {
            XCTAssertEqual(error as? ServiceError, .rejected(500))
        }
        XCTAssertEqual(otherStore.token, "T1", "anderer Fehler laesst die Sitzung unveraendert")
        XCTAssertEqual(other.status, .signedIn)
    }

    // MARK: AC-18

    /// Verhalten: Die drei Routen senden POST mit Bearer, Content-Type, X-Device (claim, result) und dem richtigen
    /// Koerper; Statuscodes werden auf die ServiceError-Faelle abgebildet, ohne Token oder Koerper preiszugeben.
    func testServiceClientLieferungsRouten() async throws {
        let device = UUID(uuidString: "CCCCCCCC-0000-4000-8000-00000000AAAA")!
        let secret = "tok-geheim"
        let marker = "KOERPER-MARKE"

        // claim 204 -> nil
        let none = SyncWire(claim: [.answer(204, Data())])
        let nothing = try await ServiceClient(baseURL: Self.base, transport: none).claimDelivery(token: secret, device: device)
        XCTAssertNil(nothing)
        let raw6 = await none.requests.first
        let claimRequest = try XCTUnwrap(raw6)
        XCTAssertEqual(claimRequest.httpMethod, "POST")
        XCTAssertEqual(claimRequest.url, URL(string: "https://example.test/app/deliveries/claim"))
        XCTAssertEqual(claimRequest.value(forHTTPHeaderField: "Authorization"), "Bearer \(secret)")
        XCTAssertEqual(claimRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(UUID(uuidString: claimRequest.value(forHTTPHeaderField: "X-Device") ?? ""), device)
        let claimBody = try XCTUnwrap(claimRequest.httpBody)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: claimBody) as? NSDictionary, [:] as NSDictionary, "Koerper {}")

        // claim 200 -> (deliveryId, rohe Lieferung)
        let object = deliveryObject(uid(5), items: [programItem()])
        let given = SyncWire(claim: [envelope(uid(5), delivery: object)])
        let claimed = try await ServiceClient(baseURL: Self.base, transport: given).claimDelivery(token: secret, device: device)
        let answer = try XCTUnwrap(claimed)
        XCTAssertEqual(answer.deliveryId, uid(5))
        XCTAssertEqual(try JSONSerialization.jsonObject(with: answer.delivery) as? NSDictionary, object as NSDictionary)

        // result
        let report = SyncWire(result: [.answer(204, Data())])
        let payload = Data("{\"deliveryId\":\"x\",\"outcome\":\"accepted\"}".utf8)
        try await ServiceClient(baseURL: Self.base, transport: report).reportResult(token: secret, device: device, body: payload)
        let raw7 = await report.requests.first
        let resultRequest = try XCTUnwrap(raw7)
        XCTAssertEqual(resultRequest.httpMethod, "POST")
        XCTAssertEqual(resultRequest.url, URL(string: "https://example.test/app/deliveries/result"))
        XCTAssertEqual(resultRequest.value(forHTTPHeaderField: "Authorization"), "Bearer \(secret)")
        XCTAssertEqual(resultRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(UUID(uuidString: resultRequest.value(forHTTPHeaderField: "X-Device") ?? ""), device)
        XCTAssertEqual(resultRequest.httpBody, payload, "der Koerper geht unveraendert raus")

        // transcript
        let transcript = SyncWire(transcript: [.answer(204, Data())])
        let bytes = Data("{\"version\":1}\n".utf8)
        try await ServiceClient(baseURL: Self.base, transport: transcript).sendTranscript(token: secret, data: bytes)
        let raw8 = await transcript.requests.first
        let transcriptRequest = try XCTUnwrap(raw8)
        XCTAssertEqual(transcriptRequest.httpMethod, "POST")
        XCTAssertEqual(transcriptRequest.url, URL(string: "https://example.test/app/transcript"))
        XCTAssertEqual(transcriptRequest.value(forHTTPHeaderField: "Authorization"), "Bearer \(secret)")
        XCTAssertEqual(transcriptRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(transcriptRequest.httpBody, bytes)

        // Fehlerabbildung auf allen drei Routen
        let table: [(Int, ServiceError)] = [(401, .unauthorized), (503, .unavailable), (409, .rejected(409)), (500, .rejected(500))]
        for (status, expected) in table {
            let failing = Data(marker.utf8)
            let routes: [(String, (ServiceClient) async throws -> Void)] = [
                ("claim", { _ = try await $0.claimDelivery(token: secret, device: device) }),
                ("result", { try await $0.reportResult(token: secret, device: device, body: Data(marker.utf8)) }),
                ("transcript", { try await $0.sendTranscript(token: secret, data: Data(marker.utf8)) }),
            ]
            for (name, call) in routes {
                let wire = SyncWire(claim: [.answer(status, failing)], result: [.answer(status, failing)],
                                    transcript: [.answer(status, failing)])
                do {
                    try await call(ServiceClient(baseURL: Self.base, transport: wire))
                    XCTFail("\(name) \(status): Fehler erwartet")
                } catch {
                    XCTAssertEqual(error as? ServiceError, expected, "\(name) \(status)")
                    let text = String(describing: error) + String(reflecting: error)
                    XCTAssertFalse(text.contains(secret), "kein Token im Fehler: \(name) \(status)")
                    XCTAssertFalse(text.contains(marker), "kein Koerper im Fehler: \(name) \(status)")
                }
            }
        }

        // unlesbare 200 bei claim
        for body in ["kein json", "{\"delivery\":{}}", "{\"deliveryId\":\"x\"}", "[]"] {
            let wire = SyncWire(claim: [.answer(200, Data(body.utf8))])
            do {
                _ = try await ServiceClient(baseURL: Self.base, transport: wire).claimDelivery(token: secret, device: device)
                XCTFail("invalidResponse erwartet fuer \(body)")
            } catch {
                XCTAssertEqual(error as? ServiceError, .invalidResponse, body)
            }
        }
    }

    // MARK: AC-19

    /// Verhalten: Der Abgleich ist unter Tests stumm: wahr bei Startargument `enable-testing` oder gesetztem
    /// `XCTestConfigurationFilePath`, sonst falsch; im laufenden Test-Host ist er stumm.
    func testWaechterIstStummUnterTests() {
        XCTAssertTrue(ClaudeSync.isSilent(arguments: ["app", "enable-testing"], environment: [:]))
        XCTAssertTrue(ClaudeSync.isSilent(arguments: ["enable-testing"], environment: ["PATH": "/usr/bin"]))
        XCTAssertTrue(ClaudeSync.isSilent(arguments: [], environment: ["XCTestConfigurationFilePath": "/tmp/x.xctestconfiguration"]))
        XCTAssertFalse(ClaudeSync.isSilent(arguments: [], environment: [:]))
        XCTAssertFalse(ClaudeSync.isSilent(arguments: ["app", "-other"], environment: ["PATH": "/usr/bin"]))
        XCTAssertTrue(ClaudeSync.isSilent(arguments: ProcessInfo.processInfo.arguments,
                                          environment: ProcessInfo.processInfo.environment),
                      "im Test-Host laeuft kein Abgleich")
    }
}
