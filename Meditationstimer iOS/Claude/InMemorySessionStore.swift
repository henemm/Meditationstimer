import Foundation
import Synchronization

/// Sitzungsspeicher im Arbeitsspeicher: für die Tests, später unter `--ui-testing`.
/// Arbeitet fehlerfrei, solange kein Fehler eingespeist wird.
final class InMemorySessionStore: SessionStoring {
    private struct Contents {
        var token: String?
        var failLoad = false, failSave = false, failClear = false
    }

    private let contents: Mutex<Contents>

    init(token: String? = nil) {
        contents = Mutex(Contents(token: token))
    }

    var token: String? { contents.withLock { $0.token } }

    /// Das nächste hier genannte `load`, `save` oder `clear` wirft einmalig `SessionStoreError.injected`.
    func failNext(load: Bool = false, save: Bool = false, clear: Bool = false) {
        contents.withLock {
            $0.failLoad = $0.failLoad || load
            $0.failSave = $0.failSave || save
            $0.failClear = $0.failClear || clear
        }
    }

    func load() throws -> String? {
        try contents.withLock {
            if $0.failLoad { $0.failLoad = false; throw SessionStoreError.injected }
            return $0.token
        }
    }

    func save(_ token: String) throws {
        try contents.withLock {
            if $0.failSave { $0.failSave = false; throw SessionStoreError.injected }
            $0.token = token
        }
    }

    func clear() throws {
        try contents.withLock {
            if $0.failClear { $0.failClear = false; throw SessionStoreError.injected }
            $0.token = nil
        }
    }
}
