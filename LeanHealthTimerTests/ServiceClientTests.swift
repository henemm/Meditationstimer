//
//  ServiceClientTests.swift
//  LeanHealthTimerTests
//
//  TDD RED #57 Schnitt 2, Runde 2a: ServiceClient (Auth-Routen) hinter der Transport-Naht.
//  Spec: docs/specs/features/feature-57-s2-serviceclient.md (Regeln 1-7, AC-1 bis AC-10).
//  Es geht nie Netzwerkverkehr hinaus; alle Tests laufen ueber die Attrappe `FakeTransport`.
//

import XCTest
import Foundation
@testable import Lean_Health_Timer

// MARK: - Attrappe

/// Attrappe fuer `HTTPTransport`: zeichnet jede Anfrage auf und liefert vorbereitete Antworten der Reihe nach
/// (die letzte Antwort wird wiederholt).
actor FakeTransport: HTTPTransport {
    enum Reply {
        case answer(Int, Data)
        case fail(any Error)
    }

    private var replies: [Reply]
    private(set) var requests: [URLRequest] = []

    init(_ replies: [Reply]) { self.replies = replies }

    init(status: Int, body: String = "") { self.replies = [.answer(status, Data(body.utf8))] }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let reply = replies.count > 1 ? replies.removeFirst() : replies[0]
        switch reply {
        case .answer(let status, let data):
            let response = HTTPURLResponse(url: request.url!, statusCode: status,
                                           httpVersion: "HTTP/1.1", headerFields: nil)!
            return (data, response)
        case .fail(let error):
            throw error
        }
    }
}

/// Eigener Fehler, um das unveraenderte Durchreichen zu pruefen.
private struct OwnError: Error, Equatable { let id: Int }

// MARK: - Tests

final class ServiceClientTests: XCTestCase {

    private let base = URL(string: "https://example.test")!

    private func client(_ transport: FakeTransport) -> ServiceClient {
        ServiceClient(baseURL: base, transport: transport)
    }

    private func tokenBody(_ token: String = "tok-1") -> String { "{\"sessionToken\":\"\(token)\"}" }

    /// Faengt den Fehler eines Aufrufs; Erfolg ist ein Testfehler.
    private func caught<T>(_ op: () async throws -> T, file: StaticString = #filePath, line: UInt = #line) async -> (any Error)? {
        do {
            _ = try await op()
            XCTFail("Fehler erwartet, aber der Aufruf gelang", file: file, line: line)
            return nil
        } catch {
            return error
        }
    }

    // AC-1
    func testAnmeldungSendetPfadMethodeKoepfeUndKoerper() async throws {
        let fake = FakeTransport(status: 200, body: tokenBody())
        _ = try await client(fake).signIn(identityToken: "idt", nonce: "roh", code: "cde")

        let requests = await fake.requests
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url, URL(string: "https://example.test/auth/apple"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(request.timeoutInterval, 15)
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["identityToken", "nonce", "code"])
        XCTAssertEqual(object["identityToken"] as? String, "idt")
        XCTAssertEqual(object["nonce"] as? String, "roh")
        XCTAssertEqual(object["code"] as? String, "cde")
    }

    // AC-2
    func testAnmeldungLiefertSitzungstoken() async throws {
        let fake = FakeTransport(status: 200, body: tokenBody("tok-1"))
        let token = try await client(fake).signIn(identityToken: "idt", nonce: "roh", code: "cde")
        XCTAssertEqual(token, "tok-1")
    }

    // AC-3
    func testAbmeldenSendetBearerOhneKoerper() async throws {
        let fake = FakeTransport(status: 204)
        try await client(fake).logout(sessionToken: "tok-1")
        let requests = await fake.requests
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url, URL(string: "https://example.test/auth/logout"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok-1")
        XCTAssertNil(request.httpBody)
    }

    func testKontoLoeschenSendetBearerOhneKoerper() async throws {
        let fake = FakeTransport(status: 204)
        try await client(fake).deleteAccount(sessionToken: "tok-1")
        let requests = await fake.requests
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url, URL(string: "https://example.test/auth/delete"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer tok-1")
        XCTAssertNil(request.httpBody)
    }

    // AC-4
    private let statusMap: [(Int, ServiceError)] = [
        (401, .unauthorized), (503, .unavailable), (400, .rejected(400)), (405, .rejected(405)),
        (413, .rejected(413)), (415, .rejected(415)), (500, .rejected(500)),
    ]

    func testStatuscodesWerdenAufServiceErrorAbgebildet() async {
        for (status, expected) in statusMap {
            let fake = FakeTransport(status: status)
            let error = await caught { try await client(fake).signIn(identityToken: "i", nonce: "n", code: "c") }
            XCTAssertEqual(error as? ServiceError, expected, "signIn bei Status \(status)")
        }
    }

    func testAbmeldenUndLoeschenBildenStatuscodesAb() async {
        for (status, expected) in statusMap + [(200, ServiceError.rejected(200))] {
            let fake = FakeTransport(status: status)
            let outError = await caught { try await client(fake).logout(sessionToken: "tok-1") }
            XCTAssertEqual(outError as? ServiceError, expected, "logout bei Status \(status)")
            let delError = await caught { try await client(fake).deleteAccount(sessionToken: "tok-1") }
            XCTAssertEqual(delError as? ServiceError, expected, "deleteAccount bei Status \(status)")
        }
    }

    // AC-5
    func testAnmeldung401IstUnauthorizedUndVonAnderenFehlernUnterscheidbar() async {
        let fake = FakeTransport(status: 401)
        let error = await caught { try await client(fake).signIn(identityToken: "i", nonce: "n", code: "c") }
        XCTAssertEqual(error as? ServiceError, .unauthorized)
        XCTAssertNotEqual(error as? ServiceError, .unavailable)
        XCTAssertNotEqual(error as? ServiceError, .rejected(401))
    }

    // AC-6
    func testAnmeldungLeererOderFehlenderTokenIstInvalidResponse() async {
        let bodies = ["{\"sessionToken\":\"\"}", "{}", "{\"sessionToken\":5}", "[]", "kein json", ""]
        for body in bodies {
            let fake = FakeTransport(status: 200, body: body)
            let error = await caught { try await client(fake).signIn(identityToken: "i", nonce: "n", code: "c") }
            XCTAssertEqual(error as? ServiceError, .invalidResponse, "Koerper: \(body)")
        }
    }

    // AC-7
    func testTransportFehlerWerdenAbgebildet() async {
        let offline = FakeTransport([.fail(URLError(.notConnectedToInternet))])
        let e1 = await caught { try await client(offline).signIn(identityToken: "i", nonce: "n", code: "c") }
        XCTAssertEqual(e1 as? ServiceError, .unavailable)

        let cancelled = FakeTransport([.fail(URLError(.cancelled))])
        let e2 = await caught { try await client(cancelled).signIn(identityToken: "i", nonce: "n", code: "c") }
        XCTAssertTrue(e2 is CancellationError, "URLError(.cancelled) muss CancellationError werden, war \(String(describing: e2))")

        let own = FakeTransport([.fail(OwnError(id: 7))])
        let e3 = await caught { try await client(own).signIn(identityToken: "i", nonce: "n", code: "c") }
        XCTAssertEqual(e3 as? OwnError, OwnError(id: 7))
    }

    // AC-8
    func testFehlerEnthaltenNieTokenNonceCodeOderKoerper() async {
        let secrets = ["geheim-idt-111", "geheim-nonce-222", "geheim-code-333", "geheim-tok-444", "geheim-body-555"]
        var errors: [any Error] = []
        for status in [400, 401, 503] {
            let fake = FakeTransport(status: status, body: "geheim-body-555")
            if let e = await caught({ try await client(fake).signIn(identityToken: "geheim-idt-111", nonce: "geheim-nonce-222", code: "geheim-code-333") }) { errors.append(e) }
            if let e = await caught({ try await client(fake).logout(sessionToken: "geheim-tok-444") }) { errors.append(e) }
            if let e = await caught({ try await client(fake).deleteAccount(sessionToken: "geheim-tok-444") }) { errors.append(e) }
        }
        let noToken = FakeTransport(status: 200, body: "{\"x\":\"geheim-body-555\"}")
        if let e = await caught({ try await client(noToken).signIn(identityToken: "geheim-idt-111", nonce: "geheim-nonce-222", code: "geheim-code-333") }) { errors.append(e) }

        XCTAssertEqual(errors.count, 10)
        for error in errors {
            let texts = [String(describing: error), error.localizedDescription, String(reflecting: error)]
            for text in texts {
                for secret in secrets {
                    XCTAssertFalse(text.contains(secret), "\(secret) steckt in \(text)")
                }
            }
        }
    }

    // AC-9
    func testAnlegenSendetNichts() async {
        let fake = FakeTransport(status: 200, body: tokenBody())
        _ = client(fake)
        let requests = await fake.requests
        XCTAssertEqual(requests.count, 0)
    }

    // AC-10
    // Abweichung von der Spec-Formulierung: `.ephemeral` setzt die Objekte auf Apple-Plattformen
    // (per Probe geprueft) nicht auf nil, sondern auf eigene In-Memory-Instanzen. Unterscheidung gegen
    // `.default`: Cache ohne Platte (diskCapacity 0), Cookies und Zugangsdaten nicht die gemeinsamen `.shared`.
    func testURLSessionTransportIstEphemeral() {
        let config = URLSessionTransport().session.configuration
        XCTAssertEqual(config.urlCache?.diskCapacity ?? 0, 0, "kein Platten-Cache")
        XCTAssertFalse(config.httpCookieStorage === HTTPCookieStorage.shared, "keine gemeinsamen Cookies")
        XCTAssertFalse(config.urlCredentialStorage === URLCredentialStorage.shared, "keine gemeinsamen Zugangsdaten")
    }
}
