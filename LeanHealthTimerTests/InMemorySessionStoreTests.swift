//
//  InMemorySessionStoreTests.swift
//  LeanHealthTimerTests
//
//  TDD RED #57 Schnitt 2, Runde 2a: Sitzungsspeicher im Arbeitsspeicher mit einspeisbaren Fehlern.
//  Spec: docs/specs/features/feature-57-s2-serviceclient.md (Regeln 8-9, AC-11 bis AC-13).
//

import XCTest
import Foundation
@testable import Lean_Health_Timer

final class InMemorySessionStoreTests: XCTestCase {

    private func assertInjected(_ op: () throws -> Void, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try op(), file: file, line: line) { error in
            XCTAssertEqual(error as? SessionStoreError, .injected, file: file, line: line)
        }
    }

    // AC-11
    func testSpeicherSpeichernLesenLoeschen() throws {
        let store = InMemorySessionStore()
        XCTAssertNil(try store.load())
        try store.save("tok-1")
        XCTAssertEqual(try store.load(), "tok-1")
        try store.clear()
        XCTAssertNil(try store.load())
        XCTAssertNoThrow(try store.clear())
    }

    func testSpeicherStartetMitToken() throws {
        let store = InMemorySessionStore(token: "start")
        XCTAssertEqual(try store.load(), "start")
        XCTAssertEqual(store.token, "start")
    }

    // AC-12
    func testFailNextSaveWirftEinmalUndAendertNichts() throws {
        let store = InMemorySessionStore()
        store.failNext(save: true)
        assertInjected { try store.save("a") }
        XCTAssertNil(store.token)
        try store.save("b")
        XCTAssertEqual(store.token, "b")
    }

    func testFailNextLoadWirftEinmal() throws {
        let store = InMemorySessionStore(token: "x")
        store.failNext(load: true)
        assertInjected { _ = try store.load() }
        XCTAssertEqual(try store.load(), "x")
    }

    func testFailNextClearWirftEinmalUndBehaeltToken() throws {
        let store = InMemorySessionStore(token: "x")
        store.failNext(clear: true)
        assertInjected { try store.clear() }
        XCTAssertEqual(store.token, "x")
        try store.clear()
        XCTAssertNil(store.token)
    }

    // AC-13
    func testFailNextMarkierungenSindUnabhaengig() throws {
        let store = InMemorySessionStore()
        store.failNext(load: true)
        XCTAssertNoThrow(try store.save("a"))
        XCTAssertNoThrow(try store.clear())
        assertInjected { _ = try store.load() }
        XCTAssertNoThrow(try store.load())
    }

    func testSpeicherNebenlaeufigerZugriff() async throws {
        let store = InMemorySessionStore()
        let values = (0..<100).map { "tok-\($0)" }
        await withTaskGroup(of: Void.self) { group in
            for value in values {
                group.addTask { try? store.save(value) }
            }
        }
        let final = try XCTUnwrap(store.token)
        XCTAssertTrue(values.contains(final))
    }
}
