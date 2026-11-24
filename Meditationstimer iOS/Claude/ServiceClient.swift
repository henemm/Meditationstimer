import Foundation

/// Schickt eine Anfrage und liefert die Antwort; in den Tests ersetzt.
protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Der echte Transport: eine ephemere Sitzung behält keine Cookies, keinen Plattencache, keine Zugangsdaten.
struct URLSessionTransport: HTTPTransport {
    let session = URLSession(configuration: .ephemeral)

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
        return (data, http)
    }
}

/// Wie ein Aufruf des Dienstes enden kann. Trägt nie Token, Nonce, Code, Körper oder URL.
enum ServiceError: Error, Equatable {
    case unauthorized
    case unavailable
    case rejected(Int)
    case invalidResponse
}

/// Die Auth-Routen des Dienstes (`server/src/auth.ts`). Anlegen sendet nichts.
struct ServiceClient: Sendable {
    let baseURL: URL
    let transport: any HTTPTransport

    init(baseURL: URL, transport: any HTTPTransport = URLSessionTransport()) {
        self.baseURL = baseURL
        self.transport = transport
    }

    /// `POST /auth/apple` mit genau `identityToken`, dem rohen `nonce` und `code`; liefert das Sitzungstoken.
    func signIn(identityToken: String, nonce: String, code: String) async throws -> String {
        var request = request(path: "auth/apple")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: ["identityToken": identityToken, "nonce": nonce, "code": code]
        )
        let body = try await send(request, success: 200)
        guard let object = try? JSONSerialization.jsonObject(with: body),
              let token = (object as? [String: Any])?["sessionToken"] as? String, !token.isEmpty else {
            throw ServiceError.invalidResponse
        }
        return token
    }

    /// `POST /auth/logout`: beendet genau diese Sitzung.
    func logout(sessionToken: String) async throws {
        _ = try await send(bearer(path: "auth/logout", sessionToken), success: 204)
    }

    /// `POST /auth/delete`: löscht das Konto hinter dieser Sitzung.
    func deleteAccount(sessionToken: String) async throws {
        _ = try await send(bearer(path: "auth/delete", sessionToken), success: 204)
    }

    /// `POST /app/deliveries/claim`: nil bei 204 (nichts offen), sonst Kennung und rohe Lieferung.
    func claimDelivery(token: String, device: UUID) async throws -> (deliveryId: String, delivery: Data)? {
        let (data, status) = try await perform(json(path: "app/deliveries/claim", token, device, Data("{}".utf8)), success: [200, 204])
        if status == 204 { return nil }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let id = root["deliveryId"] as? String, !id.isEmpty, let delivery = root["delivery"] as? [String: Any],
              let raw = try? JSONSerialization.data(withJSONObject: delivery) else { throw ServiceError.invalidResponse }
        return (id, raw)
    }

    /// `POST /app/deliveries/result`: meldet das Ergebnis einer Lieferung; 409 erscheint als `rejected(409)`.
    func reportResult(token: String, device: UUID, body: Data) async throws {
        _ = try await send(json(path: "app/deliveries/result", token, device, body), success: 204)
    }

    /// `POST /app/transcript`: die fertige Abschrift.
    func sendTranscript(token: String, data: Data) async throws {
        _ = try await send(json(path: "app/transcript", token, nil, data), success: 204)
    }

    private func json(path: String, _ token: String, _ device: UUID?, _ body: Data) -> URLRequest {
        var request = bearer(path: path, token)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let device { request.setValue(device.uuidString, forHTTPHeaderField: "X-Device") }
        request.httpBody = body
        return request
    }

    private func request(path: String) -> URLRequest {
        var request = URLRequest(
            url: baseURL.appending(path: path), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15
        )
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func bearer(path: String, _ token: String) -> URLRequest {
        var request = request(path: path)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    /// Der Erfolgsstatus der Route liefert den Körper, 401 und 503 haben je einen eigenen Fall, alles andere ist
    /// `rejected`. `URLError.cancelled` wird `CancellationError`, jeder andere `URLError` heißt „nicht erreichbar“,
    /// jeder andere Fehler wird unverändert durchgereicht.
    private func send(_ request: URLRequest, success: Int...) async throws -> Data {
        try await perform(request, success: success).data
    }

    private func perform(_ request: URLRequest, success: [Int]) async throws -> (data: Data, status: Int) {
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is URLError {
            throw ServiceError.unavailable
        }
        switch response.statusCode {
        case _ where success.contains(response.statusCode): return (data, response.statusCode)
        case 401: throw ServiceError.unauthorized
        case 503: throw ServiceError.unavailable
        default: throw ServiceError.rejected(response.statusCode)
        }
    }
}
