//
//  ClaudeVerbindungBausteineTests.swift
//  LeanHealthTimerTests
//
//  TDD RED #57 Schnitt 1: Bausteine der Claude-Verbindung (Schalter, Dienstadresse, Nonce,
//  Sitzungsspeicher im Schluesselbund, Geraete-UUID).
//  Spec: DOCS/specs/features/feature-57-s1-bausteine.md (Regeln 1-5, AC-1 bis AC-17).
//  Der echte Schluesselbund wird nie benutzt; alle Tests laufen ueber die Attrappe `FakeKeychain`.
//

import XCTest
import Security
import Foundation
@testable import Lean_Health_Timer

// MARK: - Attrappe

/// Ein aufgezeichneter Aufruf des Schluesselbunds.
struct KeychainCall {
    let op: String
    let query: [String: Any]
    let attributes: [String: Any]?
}

/// Attrappe fuer `KeychainOperations`: zeichnet jeden Aufruf auf und liefert vorbereitete Status/Daten.
/// Ohne vorbereiteten Wert antwortet sie mit `errSecInternalComponent` (unerwarteter Aufruf).
/// Im Speicher-Modus (`inMemory`) verhaelt sie sich wie ein einfacher Schluesselbund mit einem Eintrag.
final class FakeKeychain: KeychainOperations, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [KeychainCall] = []
    private var addStatuses: [OSStatus]
    private var copyResults: [(OSStatus, Data?)]
    private var updateStatuses: [OSStatus]
    private var deleteStatuses: [OSStatus]
    private let memory: Bool
    private var stored: Data?

    init(add: [OSStatus] = [], copy: [(OSStatus, Data?)] = [],
         update: [OSStatus] = [], delete: [OSStatus] = [], inMemory: Bool = false) {
        addStatuses = add
        copyResults = copy
        updateStatuses = update
        deleteStatuses = delete
        memory = inMemory
    }

    static func inMemory() -> FakeKeychain { FakeKeychain(inMemory: true) }

    var calls: [KeychainCall] { lock.withLock { _calls } }
    var ops: [String] { calls.map(\.op) }
    func calls(_ op: String) -> [KeychainCall] { calls.filter { $0.op == op } }

    private func next<T>(_ list: inout [T], fallback: T) -> T {
        list.isEmpty ? fallback : list.removeFirst()
    }

    func add(_ attributes: [String: Any]) -> OSStatus {
        lock.withLock {
            _calls.append(KeychainCall(op: "add", query: attributes, attributes: nil))
            if memory {
                if stored != nil { return errSecDuplicateItem }
                stored = attributes[kSecValueData as String] as? Data
                return errSecSuccess
            }
            return next(&addStatuses, fallback: errSecInternalComponent)
        }
    }

    func copyMatching(_ query: [String: Any]) -> (OSStatus, Data?) {
        lock.withLock {
            _calls.append(KeychainCall(op: "copy", query: query, attributes: nil))
            if memory { return stored == nil ? (errSecItemNotFound, nil) : (errSecSuccess, stored) }
            return next(&copyResults, fallback: (errSecInternalComponent, nil))
        }
    }

    func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus {
        lock.withLock {
            _calls.append(KeychainCall(op: "update", query: query, attributes: attributes))
            if memory {
                guard stored != nil else { return errSecItemNotFound }
                stored = attributes[kSecValueData as String] as? Data
                return errSecSuccess
            }
            return next(&updateStatuses, fallback: errSecInternalComponent)
        }
    }

    func delete(_ query: [String: Any]) -> OSStatus {
        lock.withLock {
            _calls.append(KeychainCall(op: "delete", query: query, attributes: nil))
            if memory {
                if stored == nil { return errSecItemNotFound }
                stored = nil
                return errSecSuccess
            }
            return next(&deleteStatuses, fallback: errSecInternalComponent)
        }
    }
}

// MARK: - Tests

final class ClaudeVerbindungBausteineTests: XCTestCase {

    private let fallback = URL(string: "https://habits.henemm.com")!
    private let sessionService = "henemm.Meditationstimer-iOS.claude.session"
    private let deviceService = "henemm.Meditationstimer-iOS.claude.device"

    // MARK: Hilfen

    private func info(_ url: Any) -> [String: Any] { ["HHServiceURL": url] }

    private func assertThrows<T, E: Error & Equatable>(_ expected: E, _ body: () throws -> T,
                                                       file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try body(), file: file, line: line) { error in
            XCTAssertEqual(error as? E, expected, "unerwarteter Fehler: \(error)", file: file, line: line)
        }
    }

    private func assertEntry(_ query: [String: Any], service: String, account: String,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(query[kSecClass as String] as? String, kSecClassGenericPassword as String, file: file, line: line)
        XCTAssertEqual(query[kSecAttrService as String] as? String, service, file: file, line: line)
        XCTAssertEqual(query[kSecAttrAccount as String] as? String, account, file: file, line: line)
        XCTAssertEqual(query[kSecUseDataProtectionKeychain as String] as? Bool, true, file: file, line: line)
        XCTAssertNil(query[kSecAttrSynchronizable as String], "nie synchronisiert", file: file, line: line)
    }

    private func assertAddAttributes(_ attributes: [String: Any], service: String, account: String,
                                     file: StaticString = #filePath, line: UInt = #line) {
        assertEntry(attributes, service: service, account: account, file: file, line: line)
        XCTAssertEqual(attributes[kSecAttrAccessible as String] as? String,
                       kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String, file: file, line: line)
        XCTAssertNotNil(attributes[kSecValueData as String] as? Data, file: file, line: line)
    }

    private func assertReadQuery(_ query: [String: Any], service: String, account: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        assertEntry(query, service: service, account: account, file: file, line: line)
        XCTAssertEqual(query[kSecReturnData as String] as? Bool, true, file: file, line: line)
        XCTAssertEqual(query[kSecMatchLimit as String] as? String, kSecMatchLimitOne as String, file: file, line: line)
    }

    // MARK: AC-1 bis AC-4: Schalter

    /// Verhalten: Ein Release-Bau ohne Eintrag hat die Claude-Verbindung aus.
    func testSchalterReleaseOhneEintragIstAus() {
        XCTAssertFalse(ClaudeWiring.isEnabled(info: [:], arguments: [], debugBuild: false))
        XCTAssertFalse(ClaudeWiring.isEnabled(info: nil, arguments: [], debugBuild: false))
    }

    /// Verhalten: Im Debug-Bau ist die Verbindung an.
    func testSchalterDebugBauIstAn() {
        XCTAssertTrue(ClaudeWiring.isEnabled(info: [:], arguments: [], debugBuild: true))
    }

    /// Verhalten: Das Startargument enable-testing schaltet ein, andere Argumente nicht.
    func testSchalterStartargumentEnableTestingIstAn() {
        XCTAssertTrue(ClaudeWiring.isEnabled(info: [:], arguments: ["enable-testing"], debugBuild: false))
        XCTAssertFalse(ClaudeWiring.isEnabled(info: [:], arguments: ["uitest-disk-store"], debugBuild: false))
    }

    /// Verhalten: Nur ein echtes Bool true im Info-Wert schaltet ein.
    func testSchalterInfoWertNurEchtesBoolTrueSchaltetEin() {
        func enabled(_ value: Any) -> Bool {
            ClaudeWiring.isEnabled(info: ["HHClaudeEnabled": value], arguments: [], debugBuild: false)
        }
        XCTAssertTrue(enabled(true))
        XCTAssertFalse(enabled(false))
        XCTAssertFalse(enabled("YES"))
        XCTAssertFalse(enabled("true"))
        XCTAssertFalse(enabled(1))
        XCTAssertFalse(enabled(0))
    }

    // MARK: AC-5 bis AC-7: Dienstadresse

    /// Verhalten: Fehlende oder kaputte Adresse faellt auf die Vorgabe zurueck.
    func testDienstadresseFehlendOderKaputtFaelltAufVorgabe() {
        XCTAssertEqual(ClaudeWiring.fallbackURL, fallback)
        XCTAssertEqual(ClaudeWiring.serviceURL(info: [:], allowsLocalHTTP: false), fallback)
        XCTAssertEqual(ClaudeWiring.serviceURL(info: nil, allowsLocalHTTP: false), fallback)
        XCTAssertEqual(ClaudeWiring.serviceURL(info: info(""), allowsLocalHTTP: false), fallback)
        XCTAssertEqual(ClaudeWiring.serviceURL(info: info(42), allowsLocalHTTP: false), fallback)
        XCTAssertEqual(ClaudeWiring.serviceURL(info: info("nicht parsbar %%% ::"), allowsLocalHTTP: false), fallback)
        XCTAssertEqual(ClaudeWiring.serviceURL(info: info("ftp://x.example"), allowsLocalHTTP: false), fallback)
        XCTAssertEqual(ClaudeWiring.serviceURL(info: info("https://"), allowsLocalHTTP: false), fallback)
    }

    /// Verhalten: Eine https-Adresse wird uebernommen, egal ob lokales http erlaubt ist.
    func testDienstadresseHttpsWirdUebernommen() {
        let url = URL(string: "https://dienst.example.org")!
        XCTAssertEqual(ClaudeWiring.serviceURL(info: info("https://dienst.example.org"), allowsLocalHTTP: false), url)
        XCTAssertEqual(ClaudeWiring.serviceURL(info: info("https://dienst.example.org"), allowsLocalHTTP: true), url)
    }

    /// Verhalten: http gilt nur fuer localhost/127.0.0.1 und nur, wenn lokales http erlaubt ist.
    func testDienstadresseHttpNurLocalhostImDebug() {
        for text in ["http://localhost:3000", "http://127.0.0.1:3000"] {
            XCTAssertEqual(ClaudeWiring.serviceURL(info: info(text), allowsLocalHTTP: true), URL(string: text)!)
            XCTAssertEqual(ClaudeWiring.serviceURL(info: info(text), allowsLocalHTTP: false), fallback)
        }
        XCTAssertEqual(ClaudeWiring.serviceURL(info: info("http://fremd.example.org"), allowsLocalHTTP: true), fallback)
    }

    // MARK: AC-8, AC-9: Nonce

    /// Verhalten: Die Nonce ist 43 Zeichen base64url und jedes Mal anders.
    func testNonceHatDreiundvierzigZeichenBase64UrlUndIstEinmalig() throws {
        let first = try Nonce()
        let second = try Nonce()
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        for nonce in [first, second] {
            XCTAssertEqual(nonce.raw.count, 43)
            XCTAssertTrue(nonce.raw.unicodeScalars.allSatisfy { allowed.contains($0) }, nonce.raw)
            XCTAssertFalse(nonce.raw.contains("="))
            XCTAssertFalse(nonce.raw.contains("+"))
            XCTAssertFalse(nonce.raw.contains("/"))
        }
        XCTAssertNotEqual(first.raw, second.raw)
    }

    /// Verhalten: Der Hash ist SHA-256 als kleingeschriebenes Hex (Testvektoren).
    func testNonceHashEntsprichtSha256Vektor() {
        XCTAssertEqual(Nonce(raw: "abc").hashed,
                       "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        XCTAssertEqual(Nonce.hash(""),
                       "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        let hashed = Nonce(raw: "irgendein-wert").hashed
        XCTAssertEqual(hashed.count, 64)
        XCTAssertTrue(hashed.allSatisfy { "0123456789abcdef".contains($0) }, hashed)
    }

    // MARK: AC-10 bis AC-14: Sitzungsspeicher

    /// Verhalten: Gespeicherte Sitzung wird gelesen, nach dem Loeschen ist sie weg.
    func testSitzungSpeichernLesenLoeschen() throws {
        let store = KeychainSessionStore(operations: FakeKeychain.inMemory())
        try store.save("tok-1")
        XCTAssertEqual(try store.load(), "tok-1")
        try store.clear()
        XCTAssertNil(try store.load())
    }

    /// Verhalten: Die Schluesselbund-Abfragen tragen die richtigen Kennungen und Schutzklasse.
    func testSitzungAbfragenTragenKennungenUndZugriffsklasse() throws {
        let fake = FakeKeychain.inMemory()
        let store = KeychainSessionStore(operations: fake)
        try store.save("tok-1")
        _ = try store.load()
        try store.clear()
        XCTAssertEqual(fake.ops, ["add", "copy", "delete"])
        assertAddAttributes(fake.calls("add")[0].query, service: sessionService, account: "session")
        assertReadQuery(fake.calls("copy")[0].query, service: sessionService, account: "session")
        assertEntry(fake.calls("delete")[0].query, service: sessionService, account: "session")
    }

    /// Verhalten: Ein vorhandener Eintrag wird nur im Wert aktualisiert, nie vorher geloescht.
    func testSitzungDuplikatAktualisiertNurDenWert() throws {
        let fake = FakeKeychain(add: [errSecDuplicateItem], update: [errSecSuccess])
        try KeychainSessionStore(operations: fake).save("neu")
        XCTAssertEqual(fake.ops, ["add", "update"])
        XCTAssertTrue(fake.calls("delete").isEmpty)
        let update = fake.calls("update")[0]
        XCTAssertEqual(Set((update.attributes ?? [:]).keys), [kSecValueData as String])
        XCTAssertEqual(update.attributes?[kSecValueData as String] as? Data, Data("neu".utf8))
        assertEntry(update.query, service: sessionService, account: "session")
    }

    /// Verhalten: Ein Update ohne Treffer ist ein Fehler, ohne weiteren Versuch.
    func testSitzungUpdateOhneTrefferIstFehler() {
        let fake = FakeKeychain(add: [errSecDuplicateItem], update: [errSecItemNotFound])
        assertThrows(SessionStoreError.keychain(errSecItemNotFound)) {
            try KeychainSessionStore(operations: fake).save("neu")
        }
        XCTAssertEqual(fake.ops, ["add", "update"])
    }

    /// Verhalten: Nicht gefunden ist kein Fehler (load nil, clear still).
    func testSitzungNichtGefundenIstNilUndKeinFehler() throws {
        let fake = FakeKeychain(copy: [(errSecItemNotFound, nil)], delete: [errSecItemNotFound])
        let store = KeychainSessionStore(operations: fake)
        XCTAssertNil(try store.load())
        XCTAssertNoThrow(try store.clear())
    }

    /// Verhalten: -34018 ist ein Fehler und wird nie als "abgemeldet" gelesen.
    func testSitzungStatusMinus34018IstFehlerNieStillAbgemeldet() {
        let missing: OSStatus = -34018
        let fake = FakeKeychain(add: [missing], copy: [(missing, nil)], delete: [missing])
        let store = KeychainSessionStore(operations: fake)
        assertThrows(SessionStoreError.keychain(missing)) { try store.load() }
        assertThrows(SessionStoreError.keychain(missing)) { try store.save("tok") }
        assertThrows(SessionStoreError.keychain(missing)) { try store.clear() }
    }

    /// Verhalten: Leere, fehlende oder keine UTF-8-Daten sind kaputt und werden nicht ueberschrieben.
    func testSitzungLeereOderKaputteDatenSindCorruptData() {
        let broken: [Data?] = [Data(), nil, Data([0xFF, 0xFE, 0xFD])]
        for data in broken {
            let fake = FakeKeychain(copy: [(errSecSuccess, data)])
            assertThrows(SessionStoreError.corruptData) { try KeychainSessionStore(operations: fake).load() }
            XCTAssertEqual(fake.ops, ["copy"], "nach kaputten Daten nur der Lese-Aufruf")
        }
    }

    /// Verhalten: Keine Fehlerbeschreibung enthaelt je das Token.
    func testSitzungFehlerBeschreibungEnthaeltTokenNie() {
        let token = "geheimes-token-123"
        let statuses: [OSStatus] = [-34018, errSecInteractionNotAllowed, errSecParam, errSecItemNotFound]
        var scenarios: [FakeKeychain] = statuses.map { FakeKeychain(add: [$0]) }
        scenarios.append(FakeKeychain(add: [errSecDuplicateItem], update: [errSecItemNotFound]))
        scenarios.append(FakeKeychain(add: [errSecDuplicateItem], update: [-34018]))
        var failures = 0
        for fake in scenarios {
            do {
                try KeychainSessionStore(operations: fake).save(token)
            } catch {
                failures += 1
                XCTAssertFalse(String(describing: error).contains(token))
                XCTAssertFalse(error.localizedDescription.contains(token))
            }
        }
        XCTAssertEqual(failures, scenarios.count, "jedes Szenario muss scheitern")
    }

    // MARK: AC-15 bis AC-17: Geraete-UUID

    /// Verhalten: Die Geraete-UUID wird einmal erzeugt und danach wiedergelesen.
    func testGeraeteUuidWirdEinmalErzeugtUndWiedergelesen() throws {
        let fake = FakeKeychain.inMemory()
        let identity = DeviceIdentity(operations: fake)
        let first = try identity.current()
        let second = try identity.current()
        XCTAssertEqual(first, second)
        XCTAssertEqual(fake.calls("add").count, 1)
        XCTAssertTrue(fake.calls("update").isEmpty)
        XCTAssertTrue(fake.calls("delete").isEmpty)
    }

    /// Verhalten: Die Abfragen der Geraete-UUID tragen eigene Kennungen und die Schutzklasse.
    func testGeraeteUuidAbfragenTragenKennungenUndZugriffsklasse() throws {
        let fake = FakeKeychain.inMemory()
        let id = try DeviceIdentity(operations: fake).current()
        XCTAssertEqual(fake.ops, ["copy", "add"])
        assertReadQuery(fake.calls("copy")[0].query, service: deviceService, account: "device")
        let add = fake.calls("add")[0].query
        assertAddAttributes(add, service: deviceService, account: "device")
        XCTAssertEqual(add[kSecValueData as String] as? Data, Data(id.uuidString.utf8))
    }

    /// Verhalten: War ein zweiter Aufrufer schneller, wird dessen UUID erneut gelesen und geliefert.
    func testGeraeteUuidDuplikatBeimAnlegenLiestErneut() throws {
        let stored = UUID()
        let fake = FakeKeychain(add: [errSecDuplicateItem],
                                copy: [(errSecItemNotFound, nil), (errSecSuccess, Data(stored.uuidString.utf8))])
        let result = try DeviceIdentity(operations: fake).current()
        XCTAssertEqual(result, stored)
        XCTAssertEqual(fake.ops, ["copy", "add", "copy"])
        XCTAssertTrue(fake.calls("update").isEmpty)
    }

    /// Verhalten: Ein Fehlerstatus wird geworfen und nichts angelegt; auch das zweite Lesen nach Duplikat.
    func testGeraeteUuidStatusFehlerWirdGeworfenNichtAngelegt() {
        let missing: OSStatus = -34018
        let fake = FakeKeychain(copy: [(missing, nil)])
        assertThrows(DeviceIdentityError.keychain(missing)) { try DeviceIdentity(operations: fake).current() }
        XCTAssertEqual(fake.ops, ["copy"])

        let second = FakeKeychain(add: [errSecDuplicateItem],
                                  copy: [(errSecItemNotFound, nil), (errSecInteractionNotAllowed, nil)])
        assertThrows(DeviceIdentityError.keychain(errSecInteractionNotAllowed)) {
            try DeviceIdentity(operations: second).current()
        }
        XCTAssertTrue(second.calls("update").isEmpty)
    }

    /// Verhalten: Keine UUID als Daten ist ein Fehler und wird nie ersetzt.
    func testGeraeteUuidKaputteDatenSindFehlerUndWerdenNieErsetzt() {
        let broken: [Data?] = [Data("keine-uuid".utf8), Data([0xFF, 0xFE, 0xFD]), Data(), nil]
        for data in broken {
            let fake = FakeKeychain(copy: [(errSecSuccess, data)])
            assertThrows(DeviceIdentityError.corruptData) { try DeviceIdentity(operations: fake).current() }
            XCTAssertEqual(fake.ops, ["copy"], "weder add noch update noch delete")
        }
    }
}
