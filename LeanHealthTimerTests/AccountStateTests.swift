//
//  AccountStateTests.swift
//  LeanHealthTimerTests
//
//  TDD RED #57 Schnitt 2, Runde 2b: AccountState der Claude-Verbindung.
//  Spec: DOCS/specs/features/feature-57-s2b-accountstate.md (Regeln 1-12, AC-1 bis AC-14).
//  Es geht nie Netzwerkverkehr hinaus; alle Tests laufen ueber die Attrappe `Wire`.
//

import XCTest
import Foundation
@testable import Lean_Health_Timer

// MARK: - Attrappe

/// Zeichnet jede Anfrage auf und beantwortet sie mit der naechsten vorbereiteten Antwort; fuehrt `hook` einmal
/// vor der ersten Antwort aus, damit ein Test den Zustand ansehen oder neu aufrufen kann, solange die Anfrage offen ist.
private actor Wire: HTTPTransport {
    enum Reply: Equatable, Sendable { case status(Int), token(String), offline, invalid, cancel, hang }

    private(set) var requests: [URLRequest] = []
    private var replies: [Reply]
    private var hook: (@MainActor @Sendable () async -> Void)?

    init(_ replies: [Reply]) { self.replies = replies }

    func onFirst(_ hook: @escaping @MainActor @Sendable () async -> Void) { self.hook = hook }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        if let hook { self.hook = nil; await hook() }
        guard !replies.isEmpty else { throw ServiceError.rejected(599) }
        switch replies.removeFirst() {
        case .offline: throw URLError(.notConnectedToInternet)
        case .invalid: throw ServiceError.invalidResponse
        case .cancel: throw CancellationError()
        case .hang:
            try await Task.sleep(for: .seconds(3600))
            throw CancellationError()
        case .token(let token):
            return (Data("{\"sessionToken\":\"\(token)\"}".utf8), Self.response(request, 200))
        case .status(let status):
            return (Data(), Self.response(request, status))
        }
    }

    private static func response(_ request: URLRequest, _ status: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
    }
}

@MainActor
private func expectNotPossibleNow(_ state: AccountState, _ message: String = "",
                                  file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertThrowsError(try state.beginSignIn(), message, file: file, line: line) { error in
        XCTAssertEqual(error as? AccountError, .notPossibleNow, message, file: file, line: line)
    }
}

// MARK: - Tests

@MainActor
final class AccountStateTests: XCTestCase {

    private static let base = URL(string: "https://example.test")!

    private func make(_ replies: [Wire.Reply], token: String? = nil) -> (AccountState, InMemorySessionStore, Wire) {
        let wire = Wire(replies)
        let store = InMemorySessionStore(token: token)
        let state = AccountState(client: ServiceClient(baseURL: Self.base, transport: wire), store: store)
        return (state, store, wire)
    }

    private func signIn(_ state: AccountState) async throws {
        _ = try state.beginSignIn()
        await state.completeSignIn(identityToken: "id", code: "c")
    }

    private func body(_ request: URLRequest) throws -> [String: String] {
        let data = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: String])
    }

    // AC-1
    func testStartMitTokenIstAngemeldet() async {
        let (state, _, wire) = make([], token: "T1")
        XCTAssertEqual(state.status, .signedIn)
        XCTAssertNil(state.lastProblem)
        let requests = await wire.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testStartOhneTokenOderBeiLesefehlerIstAbgemeldet() async {
        let (empty, _, wire) = make([])
        let store = InMemorySessionStore(token: "T1")
        store.failNext(load: true)
        let unreadable = AccountState(client: ServiceClient(baseURL: Self.base, transport: wire), store: store)
        XCTAssertEqual(empty.status, .signedOut, "leerer Speicher")
        XCTAssertEqual(unreadable.status, .signedOut, "Lesefehler bei vorhandenem Token")
        XCTAssertNil(empty.lastProblem)
        XCTAssertNil(unreadable.lastProblem)
        let requests = await wire.requests
        XCTAssertTrue(requests.isEmpty)
    }

    // AC-2
    func testBeginSignInNurAusErlaubtenZustaenden() async throws {
        let starts: [(Wire.Reply?, AccountState.Status)] = [(nil, .signedOut), (.status(401), .notAllowed), (.status(503), .retryLater)]
        for (reply, start) in starts {
            let (state, _, _) = make(reply.map { [$0] } ?? [])
            if reply != nil { try await signIn(state) }
            XCTAssertEqual(state.status, start, "Ausgangszustand \(start)")
            let hashed = try state.beginSignIn()
            XCTAssertEqual(hashed.count, 64, "Hashlaenge ab \(start)")
            XCTAssertTrue(hashed.allSatisfy { "0123456789abcdef".contains($0) }, "Kleinbuchstaben-Hex ab \(start)")
            XCTAssertEqual(state.status, .signingIn, "Zustand nach beginSignIn ab \(start)")
        }

        let (state, _, wire) = make([.token("T1")])
        let first = try state.beginSignIn()
        expectNotPossibleNow(state, "aus signingIn")
        XCTAssertEqual(state.status, .signingIn)
        await state.completeSignIn(identityToken: "id", code: "c")
        let requests = await wire.requests
        let sent = try body(try XCTUnwrap(requests.first))
        XCTAssertEqual(Nonce.hash(try XCTUnwrap(sent["nonce"])), first)
        expectNotPossibleNow(state, "aus signedIn")
        XCTAssertEqual(state.status, .signedIn)

        let (deleting, _, deleteWire) = make([.status(204)], token: "T1")
        await deleteWire.onFirst {
            XCTAssertEqual(deleting.status, .deleting)
            expectNotPossibleNow(deleting, "aus deleting")
            XCTAssertEqual(deleting.status, .deleting)
        }
        await deleting.deleteAccount()
        XCTAssertEqual(deleting.status, .signedOut)
    }

    // AC-3
    func testKoerperTraegtRoheNonceZumHash() async throws {
        let (state, _, wire) = make([.token("T1")])
        let hashed = try state.beginSignIn()
        await state.completeSignIn(identityToken: "id-token", code: "auth-code")
        let requests = await wire.requests
        let request = try XCTUnwrap(requests.first)
        let fields = try body(request)
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(request.url?.path, "/auth/apple")
        XCTAssertEqual(Set(fields.keys), ["identityToken", "nonce", "code"])
        XCTAssertEqual(fields["identityToken"], "id-token")
        XCTAssertEqual(fields["code"], "auth-code")
        let nonce = try XCTUnwrap(fields["nonce"])
        XCTAssertEqual(nonce.count, 43)
        XCTAssertEqual(Nonce.hash(nonce), hashed)
        let (other, _, _) = make([])
        XCTAssertNotEqual(try other.beginSignIn(), hashed, "zweite AccountState braucht frische Nonce")
    }

    // AC-4
    func testCompleteSignInBrauchtOffeneNonceUndVerbrauchtSie() async throws {
        for token in [nil, "T1"] as [String?] {
            let (state, _, wire) = make([.token("T2")], token: token)
            let before = state.status
            await state.completeSignIn(identityToken: "id", code: "c")
            XCTAssertEqual(state.status, before, "ohne beginSignIn, Token \(token ?? "nil")")
            let requests = await wire.requests
            XCTAssertTrue(requests.isEmpty, "keine Anfrage ohne Nonce, Token \(token ?? "nil")")
        }
        for reply in [Wire.Reply.token("T1"), .status(401), .cancel] {
            let (state, _, wire) = make([reply, .token("T2")])
            try await signIn(state)
            let after = state.status
            await state.completeSignIn(identityToken: "id", code: "c")
            let requests = await wire.requests
            XCTAssertEqual(requests.count, 1, "Nonce nur einmal nutzbar, Antwort \(reply)")
            XCTAssertEqual(state.status, after, "Status nach zweitem Aufruf, Antwort \(reply)")
        }
    }

    // AC-5
    func testAnmeldenSpeichertUndIstAngemeldet() async throws {
        let (state, store, _) = make([.token("T1")])
        try await signIn(state)
        XCTAssertEqual(store.token, "T1")
        XCTAssertEqual(state.status, .signedIn)
        XCTAssertNil(state.lastProblem)
    }

    func testSpeicherfehlerBeiAnmeldungErgibtAbgemeldet() async throws {
        let (state, store, _) = make([.token("T1")])
        store.failNext(save: true)
        try await signIn(state)
        XCTAssertEqual(state.status, .signedOut)
        XCTAssertNil(store.token)
    }

    // AC-6
    func testAnmeldenFehlerabbildung() async throws {
        let cases: [(Wire.Reply, AccountState.Status)] = [
            (.status(401), .notAllowed), (.status(503), .retryLater), (.offline, .retryLater),
            (.status(400), .signedOut), (.status(500), .signedOut), (.token(""), .signedOut), (.cancel, .signedOut),
        ]
        for (reply, expected) in cases {
            let (state, store, _) = make([reply])
            try await signIn(state)
            XCTAssertEqual(state.status, expected, "Antwort \(reply)")
            XCTAssertNil(store.token, "Speicher leer bei Antwort \(reply)")
            if reply == .cancel { XCTAssertNil(state.lastProblem, "kein Problem bei Abbruch") }
        }
    }

    // AC-7
    func testCancelSignInNurVorDerAnfrage() async throws {
        let (state, _, wire) = make([.token("T1")])
        _ = try state.beginSignIn()
        state.cancelSignIn()
        XCTAssertEqual(state.status, .signedOut)
        await state.completeSignIn(identityToken: "id", code: "c")
        state.cancelSignIn()
        XCTAssertEqual(state.status, .signedOut)
        let requests = await wire.requests
        XCTAssertTrue(requests.isEmpty, "nach cancelSignIn keine Anfrage")

        let (signedIn, _, _) = make([], token: "T1")
        signedIn.cancelSignIn()
        XCTAssertEqual(signedIn.status, .signedIn)

        let (running, store, runningWire) = make([.token("T2")])
        await runningWire.onFirst {
            running.cancelSignIn()
            XCTAssertEqual(running.status, .signingIn, "laufende Anfrage bleibt signingIn")
        }
        try await signIn(running)
        XCTAssertEqual(running.status, .signedIn)
        XCTAssertEqual(store.token, "T2")
    }

    // AC-8
    func testSignOutRaeumtLokalZuerstUndDienstAntwortAendertNichts() async throws {
        for reply in [Wire.Reply.status(204), .status(401), .status(503), .cancel] {
            let (state, store, wire) = make([reply], token: "T1")
            await wire.onFirst {
                XCTAssertNil(store.token, "Speicher beim Eintreffen schon leer, Antwort \(reply)")
                XCTAssertEqual(state.status, .signedOut, "lokal schon abgemeldet, Antwort \(reply)")
            }
            await state.signOut()
            let requests = await wire.requests
            XCTAssertEqual(requests.count, 1, "Antwort \(reply)")
            XCTAssertEqual(requests.first?.url?.path, "/auth/logout", "Antwort \(reply)")
            XCTAssertEqual(requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer T1", "Antwort \(reply)")
            XCTAssertEqual(state.status, .signedOut, "Ende, Antwort \(reply)")
            XCTAssertNil(state.lastProblem, "Ende, Antwort \(reply)")
        }
    }

    // AC-9
    func testSignOutOhneTokenUndBeiLoeschfehler() async throws {
        let (empty, _, emptyWire) = make([])
        await empty.signOut()
        let (unreadable, unreadableStore, unreadableWire) = make([], token: "T1")
        unreadableStore.failNext(load: true)
        await unreadable.signOut()
        XCTAssertEqual(empty.status, .signedOut, "leerer Speicher")
        XCTAssertEqual(unreadable.status, .signedOut, "Lesefehler")
        let emptyRequests = await emptyWire.requests
        let unreadableRequests = await unreadableWire.requests
        XCTAssertTrue(emptyRequests.isEmpty)
        XCTAssertTrue(unreadableRequests.isEmpty)

        let (stuck, stuckStore, stuckWire) = make([.status(204)], token: "T1")
        stuckStore.failNext(clear: true)
        await stuck.signOut()
        let requests = await stuckWire.requests
        XCTAssertEqual(stuck.status, .signedOut)
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.url?.path, "/auth/logout")
    }

    // AC-10
    func testKontoLoeschenNurAusAngemeldetUndErfolg() async throws {
        let (state, store, wire) = make([.status(204)], token: "T1")
        await state.deleteAccount()
        let requests = await wire.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.url?.path, "/auth/delete")
        XCTAssertEqual(requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer T1")
        XCTAssertNil(store.token)
        XCTAssertEqual(state.status, .signedOut)
        XCTAssertNil(state.lastProblem)

        let starts: [(Wire.Reply?, AccountState.Status)] = [(nil, .signedOut), (.status(401), .notAllowed), (.status(503), .retryLater)]
        for (first, start) in starts {
            let (other, _, otherWire) = make((first.map { [$0] } ?? []) + [.status(204)])
            if first != nil { try await signIn(other) }
            await other.deleteAccount()
            XCTAssertEqual(other.status, start, "deleteAccount ohne Wirkung ab \(start)")
            let count = await otherWire.requests.count
            XCTAssertEqual(count, first == nil ? 0 : 1, "keine Anfrage ueber die Anmeldung hinaus ab \(start)")
        }

        let (signing, _, signingWire) = make([.status(204)])
        _ = try signing.beginSignIn()
        await signing.deleteAccount()
        XCTAssertEqual(signing.status, .signingIn)
        let signingRequests = await signingWire.requests
        XCTAssertTrue(signingRequests.isEmpty)

        for unreadable in [true, false] {
            let (gone, goneStore, goneWire) = make([.status(204)], token: "T1")
            if unreadable { goneStore.failNext(load: true) } else { try goneStore.clear() }
            await gone.deleteAccount()
            XCTAssertEqual(gone.status, .signedOut, unreadable ? "Lesefehler" : "Speicher leer")
            let goneRequests = await goneWire.requests
            XCTAssertTrue(goneRequests.isEmpty, unreadable ? "Lesefehler" : "Speicher leer")
        }
    }

    // AC-11
    func testKontoLoeschenFehlerabbildung() async throws {
        let cases: [(Wire.Reply, AccountState.Status, String?, AccountState.Problem?)] = [
            (.status(401), .signedOut, nil, nil),
            (.status(503), .signedIn, "T1", .retryLater), (.offline, .signedIn, "T1", .retryLater),
            (.status(500), .signedIn, "T1", .retryLater), (.invalid, .signedIn, "T1", .retryLater),
            (.cancel, .signedIn, "T1", nil),
        ]
        for (reply, status, token, problem) in cases {
            let (state, store, _) = make([reply, .status(204)], token: "T1")
            await state.deleteAccount()
            XCTAssertEqual(state.status, status, "Status bei Antwort \(reply)")
            XCTAssertEqual(store.token, token, "Token bei Antwort \(reply)")
            XCTAssertEqual(state.lastProblem, problem, "Problem bei Antwort \(reply)")
            guard status == .signedIn else { continue }
            await state.deleteAccount()
            XCTAssertEqual(state.status, .signedOut, "zweiter Versuch nach \(reply)")
            XCTAssertNil(state.lastProblem, "zweiter Versuch nach \(reply)")
            XCTAssertNil(store.token, "zweiter Versuch nach \(reply)")
        }
    }

    // AC-12
    func testVeraltete401LoeschtKeineNeueSitzung() async throws {
        let (state, store, wire) = make([.status(401)], token: "T1")
        await wire.onFirst {
            do { try store.save("T2") } catch { XCTFail("save fehlgeschlagen: \(error)") }
        }
        await state.deleteAccount()
        XCTAssertEqual(store.token, "T2")
        XCTAssertEqual(state.status, .signedIn)
    }

    // AC-13
    func testDoppelaufruefeWaehrendAnfrageSindWirkungslos() async throws {
        let (signing, signingStore, signingWire) = make([.token("T1"), .token("T2")])
        await signingWire.onFirst {
            await signing.completeSignIn(identityToken: "id", code: "c")
            await signing.signOut()
            expectNotPossibleNow(signing, "waehrend Anmeldung")
        }
        try await signIn(signing)
        let signingRequests = await signingWire.requests
        XCTAssertEqual(signingRequests.count, 1)
        XCTAssertEqual(signing.status, .signedIn)
        XCTAssertEqual(signingStore.token, "T1")

        let (deleting, deletingStore, deletingWire) = make([.status(204), .status(204)], token: "T1")
        await deletingWire.onFirst {
            await deleting.deleteAccount()
            await deleting.signOut()
            expectNotPossibleNow(deleting, "waehrend Loeschen")
            XCTAssertEqual(deleting.status, .deleting)
        }
        await deleting.deleteAccount()
        let deletingRequests = await deletingWire.requests
        XCTAssertEqual(deletingRequests.count, 1)
        XCTAssertEqual(deleting.status, .signedOut)
        XCTAssertNil(deletingStore.token)
    }

    // AC-14
    func testZustandEnthaeltWederTokenNochNonce() async throws {
        let marker = "SECRET-TOKEN"
        let (state, store, wire) = make([.token(marker), .status(503), .status(401)])
        var seen: [String] = []
        func look() { seen += [String(describing: state.status), String(describing: state.lastProblem)] }
        let hashed = try state.beginSignIn()
        await state.completeSignIn(identityToken: marker + "-id", code: marker + "-code")
        look()
        do { _ = try state.beginSignIn() } catch { seen.append(String(describing: error)) }
        await state.deleteAccount()
        look()
        await state.deleteAccount()
        look()
        let requests = await wire.requests
        let nonce = try XCTUnwrap(try body(try XCTUnwrap(requests.first))["nonce"])
        XCTAssertEqual(seen.count, 7)
        XCTAssertNil(store.token)
        for text in seen {
            XCTAssertFalse(text.contains(marker), "Marke in \(text)")
            XCTAssertFalse(text.contains(nonce), "rohe Nonce in \(text)")
            XCTAssertFalse(text.contains(hashed), "gehashte Nonce in \(text)")
        }
    }
}
