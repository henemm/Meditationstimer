//
//  ClaudeEinstellungenTests.swift
//  LeanHealthTimerTests
//
//  TDD RED #57 Schnitt 5a: Einstellungsseite "Claude-Verbindung" (AC-1 bis AC-8).
//  Spec: DOCS/specs/features/feature-57-s5-einstellungen.md (Regeln R1 bis R12)
//
//  Neue Schnittstelle laut Spec (der Developer implementiert sie danach):
//    ClaudeWiring.makeAccount(info:arguments:defaults:debugBuild:) -> AccountState?
//    ClaudeWiring.usesStandIn(arguments:) -> Bool
//    AccountState.onSessionEnded: (() -> Void)?
//
//  ANNAHME (Spec nennt die Form nicht genau): die reinen Funktionen sind statisch auf `ClaudeSettingsView`:
//    ClaudeSettingsView.lastSyncText(_ date: Date?) -> String
//    ClaudeSettingsView.hint(status: AccountState.Status, lastProblem: AccountState.Problem?) -> String?
//    ClaudeSettingsView.isBusy(_ status: AccountState.Status) -> Bool
//
//  Wege (Lehre #136: der echte Rueckruf der Verdrahtung wird geprueft, nie ein von Hand gesetzter Zustand):
//    - Stand-in-Konto aus `makeAccount` (Anmelden/Abmelden/Trennen 204): AC-1 bis AC-4 (Erfolg).
//    - Gezielte Dienstantworten (500, 401, Abbruch): ein direkt gebauter `AccountState` mit eigener Attrappe, dem der
//      Rueckruf des `makeAccount`-Kontos (`made.onSessionEnded`) zugewiesen wird, umhuellt von einem Zaehler, der den
//      echten Rueckruf weiterruft. Geprueft wird also weiter das echte Loeschen in der uebergebenen Suite.
//  Es geht nie Netzwerkverkehr hinaus.
//

import XCTest
import Foundation
@testable import Lean_Health_Timer

// MARK: - Attrappe

private actor EWire: HTTPTransport {
    enum Reply: Equatable, Sendable { case status(Int), token(String), cancel }

    private(set) var requests: [URLRequest] = []
    private var replies: [Reply]
    private var hook: (@MainActor @Sendable () async -> Void)?

    init(_ replies: [Reply]) { self.replies = replies }

    func onFirst(_ hook: @escaping @MainActor @Sendable () async -> Void) { self.hook = hook }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        if let hook { self.hook = nil; await hook() }
        guard !replies.isEmpty else { throw ServiceError.rejected(599) }
        let response: (Int) -> HTTPURLResponse = {
            HTTPURLResponse(url: request.url!, statusCode: $0, httpVersion: "HTTP/1.1", headerFields: nil)!
        }
        switch replies.removeFirst() {
        case .cancel: throw CancellationError()
        case .token(let token): return (Data("{\"sessionToken\":\"\(token)\"}".utf8), response(200))
        case .status(let status): return (Data(), response(status))
        }
    }
}

// MARK: - Tests

@MainActor
final class ClaudeEinstellungenTests: XCTestCase {

    private static let base = URL(string: "https://example.test")!
    private static let stateKey = "claudeState"
    private var suiteNames: [String] = []

    override func tearDown() {
        for name in suiteNames { UserDefaults().removePersistentDomain(forName: name) }
        suiteNames = []
        super.tearDown()
    }

    private func freshDefaults() -> UserDefaults {
        let name = "ClaudeEinstellungenTests.\(UUID().uuidString)"
        suiteNames.append(name)
        return UserDefaults(suiteName: name)!
    }

    private func seed(_ defaults: UserDefaults) -> Date {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        defaults.set(date, forKey: ClaudeSync.lastSnapshotKey)
        defaults.set(Data("{\"keep\":true}".utf8), forKey: Self.stateKey)
        return date
    }

    private func standIn(_ extra: [String] = [], defaults: UserDefaults) throws -> AccountState {
        try XCTUnwrap(ClaudeWiring.makeAccount(info: nil, arguments: ["enable-testing"] + extra,
                                               defaults: defaults, debugBuild: true))
    }

    private func signInStandIn(_ account: AccountState) async throws {
        _ = try account.beginSignIn()
        await account.completeSignIn(identityToken: "uitest-token", code: "uitest-code")
    }

    /// Direkt gebautes Konto mit Attrappe; Rueckruf = der echte der Verdrahtung, umhuellt von einem Zaehler.
    private func wired(_ replies: [EWire.Reply], token: String?, defaults: UserDefaults)
        throws -> (AccountState, InMemorySessionStore, EWire, Counter) {
        let made = try standIn(defaults: defaults)
        let real = try XCTUnwrap(made.onSessionEnded, "makeAccount setzt keinen Rueckruf")
        let wire = EWire(replies)
        let store = InMemorySessionStore(token: token)
        let account = AccountState(client: ServiceClient(baseURL: Self.base, transport: wire), store: store)
        let counter = Counter()
        account.onSessionEnded = { counter.count += 1; real() }
        return (account, store, wire, counter)
    }

    @MainActor final class Counter { var count = 0 }

    // AC-1
    func testMakeAccountNilBeiAusgeschaltetemSchalter() {
        let account = ClaudeWiring.makeAccount(info: nil, arguments: [], defaults: freshDefaults(), debugBuild: false)
        XCTAssertNil(account, "ohne Schalter kein Konto (Store-Version, keine Zeile)")
    }

    func testMakeAccountUnterEnableTestingHatKontoAberKeinenAbgleich() async throws {
        let account = try standIn(defaults: freshDefaults())
        XCTAssertEqual(account.status, .signedOut)
        XCTAssertTrue(ClaudeSync.isSilent(arguments: ["enable-testing"], environment: [:]), "Konto ja, Abgleich nein")
        XCTAssertTrue(ClaudeWiring.usesStandIn(arguments: ["enable-testing"]))
        XCTAssertFalse(ClaudeWiring.usesStandIn(arguments: []))
        try await signInStandIn(account)
        XCTAssertEqual(account.status, .signedIn, "Stand-in meldet an, ohne echtes Netz")
    }

    // AC-2
    func testStandInAusgaengeZugelassenNichtZugelassenSpaeter() async throws {
        let cases: [(String?, AccountState.Status)] = [
            (nil, .signedIn), ("uitest-claude-not-allowed", .notAllowed), ("uitest-claude-retry-later", .retryLater),
        ]
        for (argument, expected) in cases {
            let account = try standIn(argument.map { [$0] } ?? [], defaults: freshDefaults())
            try await signInStandIn(account)
            XCTAssertEqual(account.status, expected, "Argument \(argument ?? "keins")")
        }
        // Ein Token im Speicher ist an der Sitzung ablesbar: ein Abgleich mit Sitzung laeuft (nicht nil).
        let account = try standIn(defaults: freshDefaults())
        try await signInStandIn(account)
        let ran: Bool? = try await account.withSession { _ in true }
        XCTAssertEqual(ran, true, "zugelassen: Token gespeichert")
    }

    // AC-3
    func testAbmeldenLoeschtLastSnapshotAt() async throws {
        let defaults = freshDefaults()
        _ = seed(defaults)
        let account = try standIn(defaults: defaults)
        try await signInStandIn(account)
        XCTAssertNotNil(defaults.object(forKey: ClaudeSync.lastSnapshotKey))
        await account.signOut()
        XCTAssertEqual(account.status, .signedOut)
        XCTAssertNil(defaults.object(forKey: ClaudeSync.lastSnapshotKey), "Abmelden loescht lastSnapshotAt")
        XCTAssertEqual(defaults.data(forKey: Self.stateKey), Data("{\"keep\":true}".utf8), "claudeState bleibt")

        // genau einmal, auch ohne gespeichertes Token
        let (offline, _, _, counter) = try wired([.status(204)], token: nil, defaults: defaults)
        await offline.signOut()
        XCTAssertEqual(counter.count, 1, "Rueckruf genau einmal, auch ohne Token")
        let (online, _, _, onceCounter) = try wired([.status(204)], token: "T1", defaults: defaults)
        await online.signOut()
        XCTAssertEqual(onceCounter.count, 1)
    }

    // AC-4
    func testTrennenLoeschtLastSnapshotAt() async throws {
        let defaults = freshDefaults()
        _ = seed(defaults)
        let account = try standIn(defaults: defaults)
        try await signInStandIn(account)
        await account.deleteAccount()
        XCTAssertEqual(account.status, .signedOut)
        XCTAssertNil(defaults.object(forKey: ClaudeSync.lastSnapshotKey), "Trennen loescht lastSnapshotAt")
        XCTAssertNotNil(defaults.data(forKey: Self.stateKey), "claudeState bleibt")

        let (state, _, _, counter) = try wired([.status(204)], token: "T1", defaults: defaults)
        defaults.set(Date(), forKey: ClaudeSync.lastSnapshotKey)
        await state.deleteAccount()
        XCTAssertEqual(counter.count, 1)
        XCTAssertNil(defaults.object(forKey: ClaudeSync.lastSnapshotKey))
    }

    func testTrennenFehlerLoeschtNichts() async throws {
        for reply in [EWire.Reply.status(500), .cancel] {
            let defaults = freshDefaults()
            let date = seed(defaults)
            let (state, _, _, counter) = try wired([reply], token: "T1", defaults: defaults)
            await state.deleteAccount()
            XCTAssertEqual(state.status, .signedIn, "Antwort \(reply)")
            XCTAssertEqual(defaults.object(forKey: ClaudeSync.lastSnapshotKey) as? Date, date, "Antwort \(reply)")
            XCTAssertEqual(counter.count, 0, "Rueckruf ruht bei \(reply)")
        }
    }

    // AC-5
    func testUnauthorizedLoeschtLastSnapshotAt() async throws {
        // aus withSession (Abgleich)
        let defaults = freshDefaults()
        _ = seed(defaults)
        let (sync, _, _, syncCounter) = try wired([], token: "T1", defaults: defaults)
        do {
            let _: Int? = try await sync.withSession { _ in throw ServiceError.unauthorized }
            XCTFail("401 muss weitergereicht werden")
        } catch { XCTAssertEqual(error as? ServiceError, .unauthorized) }
        XCTAssertEqual(sync.status, .signedOut)
        XCTAssertNil(defaults.object(forKey: ClaudeSync.lastSnapshotKey))
        XCTAssertEqual(syncCounter.count, 1)

        // aus deleteAccount
        let other = freshDefaults()
        _ = seed(other)
        let (deleting, _, _, deleteCounter) = try wired([.status(401)], token: "T1", defaults: other)
        await deleting.deleteAccount()
        XCTAssertEqual(deleting.status, .signedOut)
        XCTAssertNil(other.object(forKey: ClaudeSync.lastSnapshotKey))
        XCTAssertEqual(deleteCounter.count, 1)
    }

    func testVeraltete401LoeschtKeinenSchluessel() async throws {
        let defaults = freshDefaults()
        let date = seed(defaults)
        let (state, store, wire, counter) = try wired([.status(401)], token: "T1", defaults: defaults)
        await wire.onFirst { do { try store.save("T2") } catch { XCTFail("save: \(error)") } }
        await state.deleteAccount()
        XCTAssertEqual(store.token, "T2")
        XCTAssertEqual(state.status, .signedIn)
        XCTAssertEqual(defaults.object(forKey: ClaudeSync.lastSnapshotKey) as? Date, date)
        XCTAssertEqual(counter.count, 0, "veraltete 401: Rueckruf ruht")
    }

    func testAnmeldefehlerLoeschtNichts() async throws {
        for status in [401, 503] {
            let defaults = freshDefaults()
            let date = seed(defaults)
            let (state, _, _, counter) = try wired([.status(status)], token: nil, defaults: defaults)
            _ = try state.beginSignIn()
            await state.completeSignIn(identityToken: "id", code: "c")
            XCTAssertEqual(defaults.object(forKey: ClaudeSync.lastSnapshotKey) as? Date, date, "Antwort \(status)")
            XCTAssertEqual(counter.count, 0, "Anmeldefehler \(status): Rueckruf ruht")
        }
    }

    // AC-6
    func testOhneRueckrufVerhaeltSichWieBisher() async throws {
        let wire = EWire([.status(204), .status(204), .status(401)])
        let store = InMemorySessionStore(token: "T1")
        let account = AccountState(client: ServiceClient(baseURL: Self.base, transport: wire), store: store)
        XCTAssertNil(account.onSessionEnded, "Standard: kein Rueckruf")
        await account.signOut()
        XCTAssertEqual(account.status, .signedOut)
        XCTAssertNil(store.token)

        let second = InMemorySessionStore(token: "T2")
        let deleting = AccountState(client: ServiceClient(baseURL: Self.base, transport: wire), store: second)
        await deleting.deleteAccount()
        XCTAssertEqual(deleting.status, .signedOut)
        XCTAssertNil(second.token)

        let third = InMemorySessionStore(token: "T3")
        let dropped = AccountState(client: ServiceClient(baseURL: Self.base, transport: wire), store: third)
        do { let _: Int? = try await dropped.withSession { _ in throw ServiceError.unauthorized } } catch {}
        XCTAssertEqual(dropped.status, .signedOut)
        XCTAssertNil(third.token)
    }

    // AC-7
    func testLetzterAbgleichTextNochNichtUndDatum() {
        let none = ClaudeSettingsView.lastSyncText(nil)
        XCTAssertEqual(none, NSLocalizedString("Not yet", comment: ""))
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let text = ClaudeSettingsView.lastSyncText(date)
        XCTAssertFalse(text.isEmpty)
        XCTAssertNotEqual(text, none)
        let year = String(Calendar.current.component(.year, from: date))
        let day = String(Calendar.current.component(.day, from: date))
        XCTAssertTrue(text.contains(year) || text.contains(day), "Text \(text) nennt weder Jahr noch Tag")
    }

    // AC-8
    func testHinweisUndBeschaeftigtJeStatus() {
        let notAllowed = ClaudeSettingsView.hint(status: .notAllowed, lastProblem: nil)
        XCTAssertTrue(notAllowed?.contains("nicht zugelassen") == true || notAllowed?.contains("not allowed") == true,
                      "notAllowed: \(notAllowed ?? "nil")")
        for (status, problem) in [(AccountState.Status.retryLater, nil), (.signedIn, .retryLater)] as [(AccountState.Status, AccountState.Problem?)] {
            let text = ClaudeSettingsView.hint(status: status, lastProblem: problem)
            XCTAssertTrue(text?.contains("später erneut") == true || text?.contains("try again later") == true,
                          "\(status) \(String(describing: problem)): \(text ?? "nil")")
        }
        XCTAssertNil(ClaudeSettingsView.hint(status: .signedOut, lastProblem: nil))
        XCTAssertNil(ClaudeSettingsView.hint(status: .signedIn, lastProblem: nil))

        let all: [AccountState.Status] = [.signedOut, .signingIn, .signedIn, .deleting, .notAllowed, .retryLater]
        for status in all {
            let expected = status == .signingIn || status == .deleting
            XCTAssertEqual(ClaudeSettingsView.isBusy(status), expected, "isBusy(\(status))")
        }
    }
}
