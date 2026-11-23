import Foundation
import Security

/// Warum die Geräte-UUID nicht gelesen oder angelegt werden konnte; trägt nie die UUID.
enum DeviceIdentityError: Error, Equatable {
    case keychain(OSStatus)
    case corruptData
}

/// Eigene Kennung dieser Installation: einmal angelegt, danach immer wiedergelesen, nie ersetzt.
struct DeviceIdentity: Sendable {
    static let entry = KeychainEntry(service: "henemm.Meditationstimer-iOS.claude.device", account: "device")

    let operations: any KeychainOperations

    init(operations: any KeychainOperations = SystemKeychain()) {
        self.operations = operations
    }

    /// Nur "nicht gefunden" legt an. Duplikat beim Anlegen: erneut lesen, nie aktualisieren. Jeder andere Status ist Fehler.
    func current() throws -> UUID {
        let (status, data) = operations.copyMatching(Self.entry.read)
        if status == errSecSuccess { return try Self.decode(data) }
        guard status == errSecItemNotFound else { throw DeviceIdentityError.keychain(status) }
        let fresh = UUID()
        let added = operations.add(Self.entry.add(Data(fresh.uuidString.utf8)))
        if added == errSecSuccess { return fresh }
        guard added == errSecDuplicateItem else { throw DeviceIdentityError.keychain(added) }
        let (again, stored) = operations.copyMatching(Self.entry.read)
        guard again == errSecSuccess else { throw DeviceIdentityError.keychain(again) }
        return try Self.decode(stored)
    }

    private static func decode(_ data: Data?) throws -> UUID {
        guard let data, let text = String(data: data, encoding: .utf8), let id = UUID(uuidString: text) else {
            throw DeviceIdentityError.corruptData
        }
        return id
    }
}
