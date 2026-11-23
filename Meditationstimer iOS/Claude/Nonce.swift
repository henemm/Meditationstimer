import CryptoKit
import Foundation
import Security

enum NonceError: Error, Equatable {
    case randomUnavailable(Int32)
}

/// Nonce für Sign in with Apple: Apple bekommt `hashed`, der Dienst `raw`.
struct Nonce: Sendable, Equatable {
    let raw: String

    /// 32 Zufallsbytes, base64url ohne Auffüllung (43 Zeichen). Versagt die Quelle, wird geworfen, nie ein schwächerer Wert.
    init() throws {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { throw NonceError.randomUnavailable(status) }
        raw = Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init(raw: String) {
        self.raw = raw
    }

    var hashed: String { Self.hash(raw) }

    static func hash(_ raw: String) -> String {
        SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
