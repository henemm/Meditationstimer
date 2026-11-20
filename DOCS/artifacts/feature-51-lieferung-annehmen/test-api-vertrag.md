# Test-API-Vertrag #51 Schnitt 1 (Lese-Modell Lieferungen)

Festgelegt in der RED-Phase vom Tech Lead, damit QA-Tests und Implementierung dieselbe Oberfläche
benutzen. Datei: `Meditationstimer iOS/Models/ClaudeDelivery.swift`, nur `import Foundation`.

```swift
struct ClaudeDelivery: Equatable {
    let format: String
    let deliveryId: String
    let source: String
    let createdAt: Date
    let why: String
    let package: ClaudePackage?
    let items: [ClaudeItem]

    static func read(_ data: Data) throws(ClaudeDeliveryError) -> ClaudeDelivery
}

struct ClaudePackage: Equatable { let packageId: String; let name: String }

enum ClaudeItem: Equatable {
    case exercise(ClaudeExercise)
    case program(ClaudeProgram)
    case breath(ClaudeBreath)
    case withdrawal(ClaudeWithdrawal)
    case unsupported(kind: String)   // reminder, challenge, tracker
}

struct ClaudeExercise: Equatable {
    let itemId: String; let revision: Int; let name: String; let nameEn: String?
    let category: String; let effect: String; let instructions: String; let notes: String?
}

struct ClaudeProgram: Equatable {
    let itemId: String; let revision: Int; let name: String; let symbol: String
    let description: String?; let rounds: Int; let steps: [ClaudeProgramStep]
}

struct ClaudeProgramStep: Equatable {
    let exerciseId: String; let workSeconds: Int; let restSeconds: Int; let hint: String?
}

struct ClaudeBreath: Equatable {
    let itemId: String; let revision: Int; let name: String; let symbol: String
    let description: String?
    let inhaleSeconds: Int; let holdInSeconds: Int; let exhaleSeconds: Int; let holdOutSeconds: Int
    let rounds: Int
}

struct ClaudeWithdrawal: Equatable { let itemId: String?; let packageId: String? }

struct ClaudeDeliveryError: Error, Equatable {
    let code: String     // "APP_CANNOT_READ" oder "KIND_NOT_SUPPORTED"
    let reason: String   // kurzer deutscher Grund, nie leer
}
```

Hinweis für die Implementierung: Im Beispielsatz liegt `number-as-float-integral.json` (ganzzahlige
Werte als Gleitkommazahl geschrieben); sie zählt zu den lesbaren Dateien.
